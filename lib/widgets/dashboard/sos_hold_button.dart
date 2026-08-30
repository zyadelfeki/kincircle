import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../services/emergency_response_service.dart';

class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    this.onTriggered,
    this.onCancel,
    this.holdDuration = const Duration(seconds: 3),
    this.compact = true,
  });

  final Future<void> Function()? onTriggered;
  final VoidCallback? onCancel;
  final Duration holdDuration;
  final bool compact;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;
  bool _isTriggered = false;
  int _lastTickSecond = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )
      ..addListener(_onAnimationProgress)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleCompleted();
        }
      });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.removeListener(_onAnimationProgress);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationProgress() {
    if (!_isHolding || _isTriggered) return;

    final double progress = _controller.value;
    final int currentSecond = (progress * widget.holdDuration.inSeconds).floor();

    if (currentSecond > _lastTickSecond) {
      _lastTickSecond = currentSecond;
      if (currentSecond == 1) {
        HapticFeedback.selectionClick();
      } else if (currentSecond == 2) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _startHold() {
    if (_isTriggered) return;
    setState(() {
      _isHolding = true;
      _lastTickSecond = 0;
    });
    HapticFeedback.selectionClick();
    _controller.forward(from: 0.0);
  }

  void _cancelHold() {
    if (!_isHolding || _isTriggered) return;
    setState(() {
      _isHolding = false;
      _lastTickSecond = 0;
    });
    _controller.reset();
    HapticFeedback.lightImpact();
    widget.onCancel?.call();
  }

  Future<void> _handleCompleted() async {
    if (_isTriggered) return;
    setState(() {
      _isHolding = false;
      _isTriggered = true;
    });

    HapticFeedback.heavyImpact();

    try {
      if (widget.onTriggered != null) {
        await widget.onTriggered!();
      } else {
        await EmergencyResponseService.triggerManualSOS();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS Alert sent to your family circle!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) {
        // Reset after 4 seconds
        _resetTimer?.cancel();
        _resetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _isTriggered = false;
              _controller.reset();
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final errorColor = palette.error;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double progress = _controller.value;
          final int remainingSec =
              (widget.holdDuration.inSeconds * (1.0 - progress)).ceil().clamp(1, widget.holdDuration.inSeconds);

          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: _isTriggered
                  ? errorColor
                  : (_isHolding
                      ? errorColor.withValues(alpha: 0.22)
                      : errorColor.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorColor,
                width: _isHolding ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Filling background / progress ring overlay
                if (_isHolding)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: progress,
                          color: errorColor,
                        ),
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTriggered ? Icons.check_circle : Icons.sos_rounded,
                        color: _isTriggered ? Colors.white : errorColor,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isTriggered
                              ? 'SENT'
                              : (_isHolding
                                  ? 'HOLD ${remainingSec}s'
                                  : 'SOS (Hold)'),
                          textAlign: TextAlign.center,
                          style: KinCircleTypography.caption12(
                            color: _isTriggered
                                ? Colors.white
                                : palette.textPrimary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill from bottom or draw a glowing perimeter
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    // Draw horizontal/proportional fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * (1.0 - progress), size.width, size.height * progress),
        const Radius.circular(10),
      ),
      fillPaint,
    );

    // Border trace stroke
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
