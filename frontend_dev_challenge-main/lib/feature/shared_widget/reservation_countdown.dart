import 'dart:async';

import 'package:flutter/material.dart';

class ReservationCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final TextStyle? style;

  const ReservationCountdown({super.key, required this.expiresAt, this.style});

  @override
  State<ReservationCountdown> createState() => _ReservationCountdownState();
}

class _ReservationCountdownState extends State<ReservationCountdown> {
  Timer? _timer;

  Duration get _remaining =>
      widget.expiresAt.difference(DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ReservationCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _start();
  }

  void _start() {
    _timer?.cancel();
    if (_remaining.isNegative) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (_remaining.isNegative) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _remaining.isNegative ? Duration.zero : _remaining;
    final m = r.inMinutes.toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    final urgent = r.inSeconds < 60;
    return Text(
      'Held for $m:$s',
      style: (widget.style ?? const TextStyle()).copyWith(
        color: urgent ? Colors.red.shade700 : null,
      ),
    );
  }
}
