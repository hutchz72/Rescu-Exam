import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../model/reservation_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';
import 'api_exception.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  void add(DealModel deal) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
    _enqueueSync(deal.id);
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
      _releaseHold(existing);
    } else {
      items.refresh();
      _enqueueSync(dealId);
    }
    _recount();
  }

  void remove(int dealId) {
    final removed = items.firstWhereOrNull((i) => i.deal.id == dealId);
    items.removeWhere((i) => i.deal.id == dealId);
    if (removed != null) _releaseHold(removed);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }

  final Map<int, Future<void>> _tails = {};
  final Map<int, int> _pending = {};

  Timer? _expiryTimer;
  final Set<String> _expiryNotified = {};

  OrderRepo get _orders => Get.find<OrderRepo>();

  CartItemModel? _find(int dealId) =>
      items.firstWhereOrNull((i) => i.deal.id == dealId);

  Future<bool> renew(int dealId) async {
    if (_find(dealId) == null) return false;
    await _enqueueSync(dealId);
    return _find(dealId)?.hasValidHold ?? false;
  }

  Future<bool> renewExpired() async {
    final ids =
        items.where((i) => !i.hasValidHold).map((i) => i.deal.id).toList();
    await Future.wait(ids.map(renew));
    return ids.every((id) => _find(id)?.hasValidHold ?? false);
  }

  void markHoldsExpired() {
    final expired = items.where((i) => i.isExpired).toList();
    for (final i in (expired.isNotEmpty ? expired : items.toList())) {
      i.holdLost = true;
    }
    _afterHoldChange();
  }

  Future<void> settle() async {
    while (_tails.isNotEmpty) {
      await Future.wait(_tails.values.toList());
    }
  }

  String get signature =>
      items.map((i) => '${i.deal.id}x${i.quantity}').join(',');

  Future<void> _enqueueSync(int dealId) {
    _pending[dealId] = (_pending[dealId] ?? 0) + 1;
    _find(dealId)?.isSyncing = true;
    final prev = _tails[dealId] ?? Future<void>.value();
    final next = prev.then((_) => _sync(dealId)).whenComplete(() {
      final left = (_pending[dealId] ?? 1) - 1;
      if (left <= 0) {
        _pending.remove(dealId);
        _tails.remove(dealId);
      } else {
        _pending[dealId] = left;
      }
      final cur = _find(dealId);
      if (cur != null) {
        cur.isSyncing = left > 0;
        items.refresh();
      }
    });
    _tails[dealId] = next;
    return next;
  }

  Future<void> _sync(int dealId) async {
    final item = _find(dealId);
    if (item == null) return;
    final held = item.reservation;
    final target = item.quantity;
    if (held != null && held.quantity == target && item.hasValidHold) return;

    try {
      final fresh = await _reserveWithRetry(dealId, target);
      if (!identical(_find(dealId), item)) {
        _releaseReservation(fresh);
        return;
      }
      item.reservation = fresh;
      item.holdLost = false;
      _expiryNotified.remove(held?.id);
      if (held != null) _releaseReservation(held);
      _afterHoldChange();
    } catch (e) {
      LogService.error('reserve failed for deal $dealId', e);
      final cur = _find(dealId);
      if (cur == null || !identical(cur, item)) return;

      final confirmed = cur.hasValidHold ? cur.reservation!.quantity : 0;
      if (target <= confirmed) return;

      final name = cur.deal.name;
      final reason = _reason(e);
      if (confirmed == 0) {
        items.removeWhere((i) => identical(i, cur));
        _afterHoldChange();
        _notify('Could not reserve',
            'Sorry, $reason, so we took $name out of your bag.');
      } else {
        cur.quantity = confirmed;
        _afterHoldChange();
        _notify('Could not add another',
            '$name: $reason. You still have $confirmed in your bag.');
      }
    }
  }

  Future<ReservationModel> _reserveWithRetry(int dealId, int quantity) async {
    try {
      return await _orders.reserve(dealId, quantity: quantity);
    } on ApiException catch (e) {
      if (e.statusCode != 409 ||
          !e.message.toLowerCase().contains('try again')) {
        rethrow;
      }
      LogService.log('retrying temporarily rejected reservation for $dealId');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _orders.reserve(dealId, quantity: quantity);
    }
  }

  String _reason(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 409) {
        if (e.message.toLowerCase().contains('not enough stock')) {
          return 'there is not enough stock left';
        }
        return 'the reservation was temporarily declined; please try again';
      }
      if (e.statusCode == 404) return 'it is no longer available';
    }
    return "we couldn't reserve it right now";
  }

  void _releaseHold(CartItemModel item) {
    final held = item.reservation;
    if (held != null) _releaseReservation(held);
  }

  void _releaseReservation(ReservationModel r) {
    if (r.isExpired) return;
    _orders.releaseReservation(r.id).catchError((Object e) {
      LogService.error('release failed for ${r.id}', e);
    });
  }

  void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    DateTime? next;
    for (final i in items) {
      final r = i.reservation;
      if (r == null || !i.hasValidHold) continue;
      if (next == null || r.expiresAt.isBefore(next)) next = r.expiresAt;
    }
    if (next == null) return;
    final wait = next.difference(DateTime.now().toUtc());
    _expiryTimer = Timer(
      (wait.isNegative ? Duration.zero : wait) +
          const Duration(milliseconds: 50),
      _onExpiryTick,
    );
  }

  void _onExpiryTick() {
    final newlyExpired = items
        .where((i) => i.isExpired && _expiryNotified.add(i.reservation!.id))
        .toList();
    items.refresh();
    if (newlyExpired.isNotEmpty) {
      final what = newlyExpired.length == 1
          ? newlyExpired.first.deal.name
          : '${newlyExpired.length} items';
      _notify('Reservation ran out',
          "Your hold on $what has ended. Tap 'Reserve again' if you still want it.");
    }
    _scheduleExpiryTimer();
  }

  void _afterHoldChange() {
    items.refresh();
    _recount();
    _scheduleExpiryTimer();
  }

  void _notify(String title, String message) {
    Get.snackbar(title, message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4));
  }

  @override
  void onClose() {
    _expiryTimer?.cancel();
    super.onClose();
  }
}
