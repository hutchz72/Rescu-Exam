import 'package:intl/intl.dart';

/// A store's pickup window. The API sends UTC instants for the Bangkok market.
class PickupWindowModel {
  static const _marketUtcOffset = Duration(hours: 7);

  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String? ?? ''),
      end: DateTime.parse(json['end'] as String? ?? ''),
    );
  }

  /// Human readable label, e.g. "17:30 – 21:00".
  String get label {
    final marketStart = start.toUtc().add(_marketUtcOffset);
    final marketEnd = end.toUtc().add(_marketUtcOffset);
    return '${DateFormat('HH:mm').format(marketStart)} – '
        '${DateFormat('HH:mm').format(marketEnd)}';
  }

  /// Whether pickup starts today.
  bool get isToday {
    final marketStart = start.toUtc().add(_marketUtcOffset);
    final marketNow = DateTime.now().toUtc().add(_marketUtcOffset);
    return marketStart.year == marketNow.year &&
        marketStart.month == marketNow.month &&
        marketStart.day == marketNow.day;
  }

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get untilStart => start.difference(DateTime.now());
}
