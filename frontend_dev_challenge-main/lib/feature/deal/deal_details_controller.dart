import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/api_exception.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  final _deal = Rxn<DealModel>();
  DealModel? get deal => _deal.value;

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;
  final isLoading = true.obs;
  final loadError = RxnString();

  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is DealModel) {
      _setDeal(argument);
      isLoading.value = false;
    } else {
      final dealId = int.tryParse(Get.parameters['id'] ?? '');
      if (dealId == null) {
        loadError.value = 'This deal link is invalid.';
        isLoading.value = false;
        LogService.error('deal details opened without a valid deal id');
      } else {
        unawaited(_loadDeal(dealId));
      }
    }

    _cartWorker = ever(cartService.itemCount, (_) {
      if (deal != null) _recheckAvailability();
    });
  }

  void _setDeal(DealModel value) {
    _deal.value = value;
    _quantityLeft.value = value.quantityLeft;
    analytics.logEvent('deal_details_view', {
      'deal_id': value.id,
      'source': Get.parameters['source'] ?? 'unknown',
    });
  }

  Future<void> _loadDeal(int id) async {
    try {
      _setDeal(await dealRepo.fetchById(id));
    } catch (e) {
      LogService.error('failed to load deal $id', e);
      loadError.value = e is ApiException
          ? e.message
          : 'Unable to load this deal. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = deal;
    if (currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    final fresh = await dealRepo.fetchById(currentDeal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    final currentDeal = deal;
    if (currentDeal == null) return;
    cartService.add(currentDeal);
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
