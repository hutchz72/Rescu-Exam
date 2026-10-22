import 'dart:async';

import 'package:get/get.dart';

import '../util/log_service.dart';
import 'fake_api_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// `deal_impression` events are additionally de-duplicated per session and
/// delivered in batches (see [trackDealImpression]).
class AnalyticsService extends GetxService {
  static const int _batchSize = 10;
  static const Duration _maxBatchAge = Duration(seconds: 15);

  final events = <AnalyticsEvent>[].obs;

  /// Deals already counted this app session (all screens share this set).
  final Set<int> _impressedDealIds = <int>{};

  /// Impressions waiting to be sent. Deliberately NOT observable: nothing in
  /// the UI listens to it.
  final List<AnalyticsEvent> _pending = <AnalyticsEvent>[];
  Timer? _flushTimer;
  bool _flushing = false;

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }

  /// Cheap pre-check so widgets can skip timers for already-counted deals.
  bool hasImpression(int dealId) => _impressedDealIds.contains(dealId);

  /// Records a `deal_impression` at most once per deal per app session and
  /// queues it for batched delivery.
  void trackDealImpression({
    required int dealId,
    required String source, // home_feed | flash_rail | search
    required int position,
  }) {
    if (!_impressedDealIds.add(dealId)) return; // already counted

    final event = AnalyticsEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    events.add(event); // shows up on the Analytics debug screen
    LogService.log('analytics: deal_impression ${event.properties}');
    _enqueue(event);
  }

  void _enqueue(AnalyticsEvent event) {
    _pending.add(event);
    if (_pending.length >= _batchSize) {
      _flush();
      return;
    }
    // 15s is measured from the FIRST unsent event: start the timer only if
    // it is not already running, never restart it for later events.
    _flushTimer ??= Timer(_maxBatchAge, _flush);
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_flushing || _pending.isEmpty) return; // `finally` below re-arms

    _flushing = true;
    final batch = List<AnalyticsEvent>.of(_pending);
    _pending.clear();
    try {
      await Get.find<FakeApiService>()
          .sendAnalyticsBatch(batch.map((e) => e.toJson()).toList());
    } catch (e) {
      // Never drop events: put them back at the front, retry on next window.
      LogService.error('analytics batch failed, will retry', e);
      _pending.insertAll(0, batch);
    } finally {
      _flushing = false;
      if (_pending.length >= _batchSize) {
        _flush();
      } else if (_pending.isNotEmpty) {
        _flushTimer ??= Timer(_maxBatchAge, _flush);
      }
    }
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    super.onClose();
  }
}
