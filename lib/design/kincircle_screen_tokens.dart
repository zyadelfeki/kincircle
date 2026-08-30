import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KinCirclePaletteData {
  final Color accent;
  final Color brand;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color cardSurface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color error;
  final Color success;
  final Color warning;
  final Color mapBackground;

  const KinCirclePaletteData({
    this.accent = const Color(0xFF00C9A7),
    this.brand = const Color(0xFF00C9A7),
    this.background = const Color(0xFF0B0F1A),
    this.surface = const Color(0xFF151A28),
    this.surfaceAlt = const Color(0xFF1A2030),
    this.cardSurface = const Color(0xFF151A28),
    this.border = const Color(0xFF1E2640),
    this.textPrimary = Colors.white,
    this.textSecondary = const Color(0xFFB0B8C4),
    this.textMuted = const Color(0xFF8A8FA8),
    this.error = const Color(0xFFFF5C7A),
    this.success = const Color(0xFF4CAF50),
    this.warning = const Color(0xFFF6AD55),
    this.mapBackground = const Color(0xFF1A2030),
  });

  static const KinCirclePaletteData dark = KinCirclePaletteData(
    accent: Color(0xFF00C9A7),
    brand: Color(0xFF00C9A7),
    background: Color(0xFF0B0F1A),
    surface: Color(0xFF151A28),
    surfaceAlt: Color(0xFF1A2030),
    cardSurface: Color(0xFF151A28),
    border: Color(0xFF1E2640),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFB0B8C4),
    textMuted: Color(0xFF8A8FA8),
    error: Color(0xFFFF5C7A),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFF6AD55),
    mapBackground: Color(0xFF1A2030),
  );

  static const KinCirclePaletteData light = KinCirclePaletteData(
    accent: Color(0xFF00C896),
    brand: Color(0xFF00C896),
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF1F5),
    cardSurface: Color(0xFFFFFFFF),
    border: Color(0xFFDDE2EA),
    textPrimary: Color(0xFF0D1117),
    textSecondary: Color(0xFF3D4A5C),
    textMuted: Color(0xFF7A8899),
    error: Color(0xFFE53E3E),
    success: Color(0xFF38A169),
    warning: Color(0xFFF6AD55),
    mapBackground: Color(0xFFE8EDF2),
  );
}

class KinCirclePalette extends InheritedWidget {
  final KinCirclePaletteData data;

  const KinCirclePalette({
    super.key,
    required this.data,
    required super.child,
  });

  static KinCirclePaletteData of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? KinCirclePaletteData.dark
        : KinCirclePaletteData.light;
  }

  @override
  bool updateShouldNotify(KinCirclePalette oldWidget) => data != oldWidget.data;

  // Legacy static constants kept for backward compat — always dark values.
  static const Color accent = Color(0xFF00C9A7);
  static const Color brand = Color(0xFF00C9A7);
  static const Color background = Color(0xFF0B0F1A);
  static const Color surface = Color(0xFF151A28);
  static const Color surfaceAlt = Color(0xFF1A2030);
  static const Color cardSurface = Color(0xFF151A28);
  static const Color border = Color(0xFF1E2640);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF8A8FA8);
  static const Color error = Color(0xFFFF5C7A);
  static const Color success = Color(0xFF4CAF50);
}

class KinCircleRadii {
  static final BorderRadius card = BorderRadius.circular(20);
  static final BorderRadius button = BorderRadius.circular(14);
  static final BorderRadius input = BorderRadius.circular(12);
  static final BorderRadius pill = BorderRadius.circular(999);
}

class KinCircleTypography {
  static TextStyle heading22({
    Color color = const Color(0xFF0D1117),
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle cardTitle16({
    Color color = const Color(0xFF0D1117),
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 16,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle body14({
    Color color = const Color(0xFF0D1117),
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle body16({
    Color color = const Color(0xFF0D1117),
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle caption12({
    Color color = const Color(0xFF7A8899),
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle caption10({
    Color color = const Color(0xFF7A8899),
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 10,
      fontWeight: weight,
      color: color,
    );
  }
}

class KinCircleDecorations {
  static BoxDecoration card({
    Color color = const Color(0xFF151A28),
    Color borderColor = const Color(0xFF1E2640),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: KinCircleRadii.card,
      border: Border.all(
        color: borderColor,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration input(KinCirclePaletteData palette) {
    return BoxDecoration(
      color: palette.surfaceAlt,
      borderRadius: KinCircleRadii.input,
      border: Border.all(
        color: palette.border,
        width: 1,
      ),
    );
  }
}

class KinCircleButtons {
  static ButtonStyle primary() {
    return ElevatedButton.styleFrom(
      backgroundColor: KinCirclePalette.accent,
      foregroundColor: Colors.black,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: KinCircleRadii.button,
      ),
      elevation: 0,
      textStyle: KinCircleTypography.body14(
        color: Colors.black,
        weight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle secondary() {
    return OutlinedButton.styleFrom(
      foregroundColor: KinCirclePalette.accent,
      minimumSize: const Size(double.infinity, 52),
      side: const BorderSide(
        color: KinCirclePalette.accent,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: KinCircleRadii.button,
      ),
      textStyle: KinCircleTypography.body14(
        color: KinCirclePalette.accent,
        weight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle ghost() {
    return TextButton.styleFrom(
      foregroundColor: KinCirclePalette.accent,
      minimumSize: const Size(0, 52),
      textStyle: KinCircleTypography.body14(
        color: KinCirclePalette.accent,
        weight: FontWeight.w600,
      ),
    );
  }
}
