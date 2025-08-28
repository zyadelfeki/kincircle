import 'package:flutter/material.dart';

class SocialAuthButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed; // Allow null to disable the button

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<SocialAuthButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _controller.forward();
  void _up(TapUpDetails _) => _controller.reverse();
  void _cancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      icon: Icon(widget.icon, size: 24.0),
      label: Text(widget.text),
      onPressed: widget.onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        minimumSize: const Size(double.infinity, 50), // Full width
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : _down,
      onTapUp: widget.onPressed == null ? null : _up,
      onTapCancel: widget.onPressed == null ? null : _cancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, _) => Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.onPressed != null
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : const [],
            ),
            child: button,
          ),
        ),
      ),
    );
  }
}
