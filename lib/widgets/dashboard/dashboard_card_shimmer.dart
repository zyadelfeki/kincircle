import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';

class DashboardCardShimmer extends StatelessWidget {
  const DashboardCardShimmer({
    super.key,
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return Shimmer.fromColors(
      baseColor: palette.surfaceAlt,
      highlightColor: palette.border,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: palette.textPrimary,
          borderRadius: KinCircleRadii.card,
        ),
      ),
    );
  }
}
