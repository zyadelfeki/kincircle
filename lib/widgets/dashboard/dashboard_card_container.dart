import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';

class DashboardCardContainer extends StatelessWidget {
  const DashboardCardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return Container(
      decoration: KinCircleDecorations.card(
        color: palette.surface,
        borderColor: palette.border,
      ),
      padding: padding,
      child: child,
    );
  }
}
