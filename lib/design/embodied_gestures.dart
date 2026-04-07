import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Embodied cognition system - tactile/haptic feedback
/// Research: Smooth swipes = Calmer brain states
/// Haptic timing = Directly influences dopamine
/// Curved motion = Organic feel
/// Texture simulation = Sensory-inscribed experiences

/// Curved gesture system
class EmbodiedGestures {
  /// Smooth swipe with curved motion and haptic feedback
  static Future<void> smoothSwipe({
    required TickerProvider vsync,
    required Function onComplete,
    Duration duration = const Duration(milliseconds: 800),
  }) async {
    HapticFeedback.mediumImpact();

    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    await controller.forward();
    controller.dispose();
    HapticFeedback.lightImpact(); // Gentle completion
    onComplete();
  }

  /// Organic drag gesture
  static Future<void> organicDrag({
    required TickerProvider vsync,
    required Offset start,
    required Offset end,
    required Function(Offset) onUpdate,
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    HapticFeedback.selectionClick();

    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    final animation = Tween<Offset>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutSine,
    ));

    animation.addListener(() {
      onUpdate(animation.value);
    });

    await controller.forward();
    controller.dispose();
    HapticFeedback.lightImpact();
  }

  /// Gentle bounce animation
  static AnimationController gentleBounce({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    HapticFeedback.lightImpact();

    return AnimationController(
      duration: duration,
      vsync: vsync,
    )..forward();
  }
}

/// Tactile feedback patterns
class TactileFeedback {
  /// Paper texture simulation
  static Future<void> paperTexture() async {
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.selectionClick();
  }

  /// Soft button press
  static void softButton() {
    HapticFeedback.lightImpact();
  }

  /// Satisfying click with double feedback
  static Future<void> satisfyingClick() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.selectionClick();
  }

  /// Gentle notification
  static void gentleNotification() {
    HapticFeedback.selectionClick();
  }

  /// Success confirmation (triple tap)
  static Future<void> successConfirmation() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.mediumImpact();
  }

  /// Error pattern
  static Future<void> errorPattern() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }
}

/// Tactile button with paper texture and haptic feedback
class TactileButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;
  final bool enableHaptics;

  const TactileButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.enableHaptics = true,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    if (widget.enableHaptics) {
      await TactileFeedback.satisfyingClick();
    }
    await _controller.forward();
    await _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: widget.color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: InkWell(
          onTap: _handlePress,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // Paper texture overlay
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sensory card with texture overlay and gentle shadow
class SensoryCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool enableHaptics;

  const SensoryCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.enableHaptics = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          if (enableHaptics) {
            TactileFeedback.softButton();
          }
          onTap!();
        }
      },
      child: Container(
        width: width,
        height: height,
        margin: margin ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          // Texture overlay
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// Smooth swipe detector for organic gestures
class SmoothSwipeDetector extends StatefulWidget {
  final Widget child;
  final Function(DragEndDetails)? onSwipeLeft;
  final Function(DragEndDetails)? onSwipeRight;
  final Function(DragEndDetails)? onSwipeUp;
  final Function(DragEndDetails)? onSwipeDown;
  final bool enableHaptics;

  const SmoothSwipeDetector({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.enableHaptics = true,
  });

  @override
  State<SmoothSwipeDetector> createState() => _SmoothSwipeDetectorState();
}

class _SmoothSwipeDetectorState extends State<SmoothSwipeDetector> {
  Offset? _startPosition;

  void _handleDragStart(DragStartDetails details) {
    _startPosition = details.globalPosition;
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_startPosition == null) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return; // Minimum swipe velocity

    if (widget.enableHaptics) {
      TactileFeedback.softButton();
    }

    if (velocity > 0) {
      // Right or down swipe
      if (details.velocity.pixelsPerSecond.dx.abs() >
          details.velocity.pixelsPerSecond.dy.abs()) {
        widget.onSwipeRight?.call(details);
      } else {
        widget.onSwipeDown?.call(details);
      }
    } else {
      // Left or up swipe
      if (details.velocity.pixelsPerSecond.dx.abs() >
          details.velocity.pixelsPerSecond.dy.abs()) {
        widget.onSwipeLeft?.call(details);
      } else {
        widget.onSwipeUp?.call(details);
      }
    }

    _startPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragEnd: _handleDragEnd,
      onVerticalDragStart: _handleDragStart,
      onVerticalDragEnd: _handleDragEnd,
      child: widget.child,
    );
  }
}

/// Tactile icon button with haptic feedback
class TactileIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final bool enableHaptics;

  const TactileIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.enableHaptics = true,
  });

  @override
  State<TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<TactileIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    if (widget.enableHaptics) {
      TactileFeedback.softButton();
    }
    await _controller.forward();
    await _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: IconButton(
        icon: Icon(widget.icon),
        color: widget.color ?? Theme.of(context).iconTheme.color,
        iconSize: widget.size,
        onPressed: _handlePress,
      ),
    );
  }
}
