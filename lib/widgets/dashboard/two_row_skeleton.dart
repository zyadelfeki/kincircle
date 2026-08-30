import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';

/// A 2-row skeleton loader: first row = 40% width, second row = 60% width,
/// 8px border radius, with smooth pulsing opacity animation.
class TwoRowSkeleton extends StatefulWidget {
  const TwoRowSkeleton({
    super.key,
    this.firstRowWidthFactor = 0.4,
    this.secondRowWidthFactor = 0.6,
    this.rowHeight = 14,
    this.spacing = 8,
  });

  final double firstRowWidthFactor;
  final double secondRowWidthFactor;
  final double rowHeight;
  final double spacing;

  @override
  State<TwoRowSkeleton> createState() => _TwoRowSkeletonState();
}

class _TwoRowSkeletonState extends State<TwoRowSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _animation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FractionallySizedBox(
                widthFactor: widget.firstRowWidthFactor,
                child: Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border, width: 1),
                  ),
                ),
              ),
              SizedBox(height: widget.spacing),
              FractionallySizedBox(
                widthFactor: widget.secondRowWidthFactor,
                child: Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border, width: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
