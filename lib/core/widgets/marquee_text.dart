import 'dart:async';

import 'package:flutter/material.dart';

/// Текст, который при переполнении прокручивается с паузами (бегущая строка).
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  bool _isPaused = false;

  static const double _step = 0.4;
  static const Duration _scrollInterval = Duration(milliseconds: 50);
  static const Duration _pauseDuration = Duration(milliseconds: 2200);

  void _startScrolling(double textWidth, double gap) {
    _timer?.cancel();
    final totalWidth = textWidth * 2 + gap;
    if (totalWidth <= 0) return;

    void scrollTick() {
      if (!mounted || !_controller.hasClients) return;
      final maxScroll = _controller.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      final offset = _controller.offset + _step;
      if (offset >= maxScroll) {
        _controller.jumpTo(maxScroll);
        _isPaused = true;
        _timer?.cancel();
        _timer = Timer(_pauseDuration, () {
          if (!mounted) return;
          _controller.jumpTo(0.0);
          _isPaused = true;
          _timer?.cancel();
          _timer = Timer(_pauseDuration, () {
            if (!mounted) return;
            _isPaused = false;
            _startScrolling(textWidth, gap);
          });
        });
        return;
      }
      _controller.jumpTo(offset);
    }

    _timer = Timer.periodic(_scrollInterval, (_) {
      if (!_isPaused) scrollTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: widget.style);
        final tp = TextPainter(
          text: span,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        final textWidth = tp.width;
        final maxWidth = constraints.maxWidth;
        const gap = 40.0;

        if (maxWidth <= 0 || textWidth <= maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final totalWidth = textWidth * 2 + gap;
        final lineHeight = (tp.height + 1).clamp(14.0, 36.0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients) _startScrolling(textWidth, gap);
        });

        return SizedBox(
          width: maxWidth,
          height: lineHeight,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                height: lineHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                      SizedBox(width: gap),
                      Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
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
