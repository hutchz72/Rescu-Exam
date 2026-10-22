import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final scrollOffset = 0.0.obs;
  bool _isRefreshing = false;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    scrollOffset.value = scrollController.offset;
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      _page = 1;
      final res = await dealRepo.fetchDeals(page: 1);
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
      refreshController.resetNoData();
    } catch (e) {
      LogService.error('refreshDeals failed', e);
      refreshController.refreshFailed();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _isRefreshing) {
      refreshController.loadComplete();
      return;
    }

    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }

    _isFetchingMore = true;
    final fetchPage = _page + 1;

    try {
      final res = await dealRepo.fetchDeals(page: fetchPage);

      if (_isRefreshing) {
        refreshController.loadComplete();
        return;
      }
      _page = fetchPage;
      _totalPages = res.totalPages;
      deals.addAll(res.items);
      refreshController.loadComplete();
    } catch (e) {
      LogService.error('loadMore failed', e);
      refreshController.loadFailed();
    } finally {
      _isFetchingMore = false;
    }
    _isFetchingMore = false;
    refreshController.loadComplete();
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
