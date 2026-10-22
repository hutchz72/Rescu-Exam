import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

/// Wraps a deal card and logs a `deal_impression` once the card has been
/// >= 50% visible for 1 continuous second.
///
/// Performance: no setState, no Obx, no extra layout/paint objects. The only
/// work is a tiny callback (debounced by [VisibilityDetectorController]) and
/// at most one Timer per currently-visible card.
class ImpressionTracker extends StatefulWidget {
  final int dealId;

  /// `home_feed`, `flash_rail` or `search`.
  final String source;

  /// Index of the card inside ITS OWN list.
  final int position;
  final Widget child;

  const ImpressionTracker({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<ImpressionTracker> createState() => _ImpressionTrackerState();
}

class _ImpressionTrackerState extends State<ImpressionTracker> {
  static const double _minFraction = 0.5;
  static const Duration _minDuration = Duration(seconds: 1);

  final AnalyticsService _analytics = Get.find<AnalyticsService>();
  Timer? _timer;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction >= _minFraction) {
      if (_timer != null) return; // already counting
      if (_analytics.hasImpression(widget.dealId)) return; // seen elsewhere
      _timer = Timer(_minDuration, _onElapsed);
    } else {
      // Dropped below 50% before 1s: not continuous -> start over next time.
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onElapsed() {
    _timer = null;
    if (!mounted) return;

    // A route pushed on top (deal page, cart, ...) keeps this screen mounted
    // and may leave the last reported visibility stale. Don't count while the
    // screen is covered; check again in a second.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _timer = Timer(_minDuration, _onElapsed);
      return;
    }

    _analytics.trackDealImpression(
      dealId: widget.dealId,
      source: widget.source,
      position: widget.position,
    );
  }

  @override
  void didUpdateWidget(ImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lists without keys (search results, refreshed feed) reuse this State
    // for a different deal: forget the old deal's progress. The new
    // VisibilityDetector (its key changes with dealId) reports afresh.
    if (oldWidget.dealId != widget.dealId ||
        oldWidget.source != widget.source) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('impression:${widget.source}:${widget.dealId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
