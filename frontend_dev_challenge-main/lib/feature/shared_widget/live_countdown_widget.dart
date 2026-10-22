import 'dart:async';
import 'package:flutter/material.dart';

class LiveCountdownWidget extends StatefulWidget {
  final DateTime? endTime;
  final TextStyle style;
  final VoidCallback onExpired;

  const LiveCountdownWidget({
    super.key,
    required this.endTime,
    required this.style,
    required this.onExpired,
  });

  @override
  State<LiveCountdownWidget> createState() => _LiveCountdownWidgetState();
}

class _LiveCountdownWidgetState extends State<LiveCountdownWidget> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _expiredNotified = false;

  bool get _hasEndTime => widget.endTime != null;
  bool get _isExpired => _hasEndTime && _remainingTime <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LiveCountdownWidget old) {
    super.didUpdateWidget(old);
    if (old.endTime != widget.endTime) {
      _expiredNotified = false;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (!_hasEndTime) return;

    _tick();
    if (!_isExpired) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.endTime!.difference(DateTime.now());
    setState(() => _remainingTime = remaining);

    if (remaining <= Duration.zero) {
      _timer?.cancel();
      if (!_expiredNotified) {
        _expiredNotified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onExpired();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasEndTime) return Text('', style: widget.style);
    if (_isExpired) return Text('Expired', style: widget.style);

    final hours = _remainingTime.inHours;
    final minutes = (_remainingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    final timeString = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';

    return Text(timeString, style: widget.style);
  }
}
