import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/binding/deal_details_binding.dart';
import 'package:rescu/feature/deal/deal_details_screen.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';
import 'package:rescu/model/reservation_model.dart';
import 'package:rescu/repository/deal_repo.dart';
import 'package:rescu/repository/order_repo.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('deep link loads the requested deal details', (tester) async {
    final dealRepo = _DeepLinkDealRepo();
    final cartService = CartService();
    Get.put<DealRepo>(dealRepo);
    Get.put(cartService);
    Get.put<OrderRepo>(_DeepLinkOrderRepo());
    Get.put(AnalyticsService());

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/deal?id=42&source=push',
        getPages: [
          GetPage(
            name: '/deal',
            page: () => const DealDetailsScreen(),
            binding: DealDetailsBinding(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(dealRepo.requestedId, 42);
    expect(find.text('Deep-linked deal'), findsOneWidget);
    expect(find.text('Loaded by deal id'), findsOneWidget);
    expect(find.text('Pickup window'), findsOneWidget);
    expect(find.text('Add to bag'), findsOneWidget);
  });
}

class _DeepLinkDealRepo extends DealRepo {
  _DeepLinkDealRepo() : super(api: FakeApiService());

  int? requestedId;

  @override
  Future<DealModel> fetchById(int id) async {
    requestedId = id;
    return DealModel(
      id: id,
      name: 'Deep-linked deal',
      description: 'Loaded by deal id',
      imageUrl: '',
      originalPrice: 100,
      price: 50,
      currencyCode: 'THB',
      quantityLeft: 2,
      storeId: 1,
      storeName: 'Store',
      storeAddress: 'Bangkok',
      lat: 13.75,
      lng: 100.5,
      rating: null,
      tags: const [],
      pickupWindow: PickupWindowModel(
        start: DateTime.utc(2026, 1, 1, 23),
        end: DateTime.utc(2026, 1, 2, 2, 30),
      ),
      flashSaleEndsAt: null,
    );
  }
}

class _DeepLinkOrderRepo extends OrderRepo {
  _DeepLinkOrderRepo() : super(api: FakeApiService());

  @override
  Future<ReservationModel> reserve(int dealId, {int quantity = 1}) async {
    return ReservationModel(
      id: 'test-hold',
      dealId: dealId,
      quantity: quantity,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }
}
