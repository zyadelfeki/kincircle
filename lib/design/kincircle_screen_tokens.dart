import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KinCirclePalette {
  static const Color background = Color(0xFF0B0F1A);
  static const Color surface = Color(0xFF151A28);
  static const Color surfaceAlt = Color(0xFF1A2030);
  static const Color border = Color(0xFF1E2640);
  static const Color accent = Color(0xFF00C9A7);
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
    Color color = KinCirclePalette.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 22,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle cardTitle16({
    Color color = KinCirclePalette.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 16,
      fontWeight: weight,
      color: color,
    );
  }

   static TextStyle body14({
     Color color = KinCirclePalette.textPrimary,
     FontWeight weight = FontWeight.w400,
   }) {
     return GoogleFonts.inter(
       fontSize: 14,
       fontWeight: weight,
       color: color,
     );
   }

   static TextStyle body16({
     Color color = KinCirclePalette.textPrimary,
     FontWeight weight = FontWeight.w400,
   }) {
     return GoogleFonts.inter(
       fontSize: 16,
       fontWeight: weight,
       color: color,
     );
   }

  static TextStyle caption12({
    Color color = KinCirclePalette.textMuted,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: weight,
      color: color,
    );
  }
}

class KinCircleDecorations {
  static BoxDecoration card({
    Color color = KinCirclePalette.surface,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: KinCircleRadii.card,
      border: Border.all(
        color: KinCirclePalette.border,
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

  static BoxDecoration input() {
    return BoxDecoration(
      color: KinCirclePalette.surfaceAlt,
      borderRadius: KinCircleRadii.input,
      border: Border.all(
        color: KinCirclePalette.border,
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
