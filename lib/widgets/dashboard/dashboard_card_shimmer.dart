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
    return Shimmer.fromColors(
      baseColor: KinCirclePalette.surfaceAlt,
      highlightColor: KinCirclePalette.border,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: KinCircleRadii.card,
        ),
      ),
    );
  }
}
