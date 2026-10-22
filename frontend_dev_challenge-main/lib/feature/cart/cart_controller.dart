import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;
  Timer? _expiryTimer;

  @override
  void onReady() {
    super.onReady();
    _checkExpiredAfterFrame();
    _expiryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _removeExpiredItems(),
    );
  }

  void _checkExpiredAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _removeExpiredItems());
  }

  @override
  void onClose() {
    _expiryTimer?.cancel();
    super.onClose();
  }

  List<String> _removeExpiredItems() {
    final now = DateTime.now();
    final expired = cartService.items.where((item) {
      final end = item.deal.flashSaleEndsAt;
      return end != null && !end.isAfter(now);
    }).toList();

    if (expired.isEmpty) return const [];

    for (final item in expired) {
      cartService.remove(item.deal.id);
    }

    final names = expired.map((i) => i.deal.name).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(
        'Deal Expired',
        '${names.join(', ')} has expired and was removed from your bag.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );
    });

    return names;
  }

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;

    final removed = _removeExpiredItems();
    if (removed.isNotEmpty || cartService.items.isEmpty) return;

    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(cartService.items.toList());
      cartService.clear();
      Get.snackbar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      Get.snackbar(
        'Checkout failed',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isCheckingOut.value = false;
    }
  }
}
