import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/pickup_window_model.dart';

void main() {
  test('DealModel parses API json', () {
    final deal = DealModel.fromJson({
      'id': 7,
      'name': 'Surprise Bakery Bag',
      'description': 'Assorted pastries',
      'imageUrl': 'https://example.com/img.jpg',
      'originalPrice': 150,
      'price': 49,
      'currencyCode': 'THB',
      'quantityLeft': 3,
      'storeId': 2,
      'storeName': 'Sunrise Bakehouse',
      'storeAddress': '1 Sukhumvit Soi 1, Bangkok',
      'lat': 13.75,
      'lng': 100.5,
      'rating': null,
      'tags': ['bestseller'],
      'pickupWindow': {
        'start': '2026-01-01T10:30:00.000Z',
        'end': '2026-01-01T14:00:00.000Z',
      },
      'flashSaleEndsAt': null,
    });

    expect(deal.id, 7);
    expect(deal.rating, isNull);
    expect(deal.discountPercent, 67);
    expect(deal.isFlashSale, isFalse);
    expect(deal.pickupWindow.start.isUtc, isTrue);
  });

  test('PickupWindowModel displays pickup times in Bangkok time', () {
    final window = PickupWindowModel(
      start: DateTime.parse('2026-06-01T23:00:00.000Z'),
      end: DateTime.parse('2026-06-02T02:30:00.000Z'),
    );

    expect(window.label, '06:00 – 09:30');
  });

  test('PickupWindowModel checks today using the Bangkok calendar date', () {
    const marketOffset = Duration(hours: 7);
    final nowInBangkok = DateTime.now().toUtc().add(marketOffset);
    final todayInBangkok = DateTime.utc(
      nowInBangkok.year,
      nowInBangkok.month,
      nowInBangkok.day,
    );
    final todayWindow = PickupWindowModel(
      start: todayInBangkok
          .add(const Duration(hours: 6))
          .subtract(marketOffset),
      end: todayInBangkok
          .add(const Duration(hours: 9, minutes: 30))
          .subtract(marketOffset),
    );
    final yesterdayWindow = PickupWindowModel(
      start: todayWindow.start.subtract(const Duration(days: 1)),
      end: todayWindow.end.subtract(const Duration(days: 1)),
    );

    expect(todayWindow.isToday, isTrue);
    expect(yesterdayWindow.isToday, isFalse);
  });
}
