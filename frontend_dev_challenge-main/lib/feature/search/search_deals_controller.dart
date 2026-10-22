import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  final searchQuery = ''.obs;
  int _searchSequence = 0;

  @override
  void onInit() {
    super.onInit();
    debounce(
      searchQuery,
      (query) => _search(query),
      time: const Duration(milliseconds: 350),
    );
  }

  void onQueryChanged(String query) {
    searchQuery.value = query;
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _searchSequence++;
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }

    final currentSequence = ++_searchSequence;

    isLoading.value = true;
    hasSearched.value = true;
    try {
      final found = await dealRepo.search(query);

      if (currentSequence == _searchSequence) {
        results.assignAll(found);
        isLoading.value = false;
      }
    } catch (e) {
      if (currentSequence == _searchSequence) {
        LogService.error('search failed', e);
        isLoading.value = false;
      }
    }
  }
}
