import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:myradio1/theme/app_theme.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double maxHeight;
  final double width;
  final Color? color;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 5,
    this.maxHeight = 24.0,
    this.width = 3.0,
    this.color,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.animateTo(0.1, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? AppTheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (index) {
            double heightFactor;
            if (widget.isPlaying) {
              // Calculate different phase offsets for each bar
              final phase = (index * math.pi / widget.barCount);
              final wave = math.sin((_controller.value * 2 * math.pi) + phase);
              heightFactor = 0.25 + (0.75 * ((wave + 1) / 2));
            } else {
              heightFactor = 0.2;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: widget.width,
              height: math.max(4.0, widget.maxHeight * heightFactor),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(widget.width / 2),
              ),
            );
          }),
        );
      },
    );
  }
}
