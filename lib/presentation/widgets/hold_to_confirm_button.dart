import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Кнопка: удержание [holdDuration] → [onConfirmed]. Фон заполняется, тряска растёт с прогрессом.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 2400),
    this.color = Colors.redAccent,
    this.height = 48,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final Color color;
  final double height;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  Ticker? _shakeTicker;
  double _shakePhase = 0;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _stopShake();
          widget.onConfirmed();
        }
      });
  }

  @override
  void dispose() {
    _stopShake();
    _progress.dispose();
    super.dispose();
  }

  void _startHold() {
    _progress.forward(from: _progress.value);
    if (_shakeTicker != null) return;
    _shakeTicker = Ticker((elapsed) {
      _shakePhase = elapsed.inMicroseconds / 1e6;
      if (mounted) setState(() {});
    })..start();
  }

  void _cancelHold() {
    if (_progress.isCompleted) return;
    _progress.reverse(from: _progress.value);
    _stopShake();
  }

  void _stopShake() {
    _shakeTicker?.stop();
    _shakeTicker?.dispose();
    _shakeTicker = null;
    _shakePhase = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final p = _progress.value;
        final shake = p * p;
        final dx = sin(_shakePhase * (8 + p * 22)) * shake * 6;
        final dy = cos(_shakePhase * (6 + p * 18)) * shake * 2.5;
        final angle = sin(_shakePhase * (10 + p * 26)) * shake * 0.04;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _startHold(),
              onPointerUp: (_) => _cancelHold(),
              onPointerCancel: (_) => _cancelHold(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.55),
                          ),
                          color: widget.color.withValues(alpha: 0.12),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: p.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(color: widget.color),
                        ),
                      ),
                      Center(
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
