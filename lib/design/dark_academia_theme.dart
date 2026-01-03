import 'package:flutter/material.dart';

/// Dark Academia theme for neurodivergent users
/// Research: Moody, detailed interfaces = Reduced anxiety
/// Nostalgic elements = Emotional regulation
/// Old-money luxury = Aspirational dopamine hits

class DarkAcademiaTheme {
  // Color palette
  static const Color backgroundDark = Color(0xFF1A1612); // Warm dark brown
  static const Color primaryBrass = Color(0xFF8B7355); // Aged brass
  static const Color cardVintage = Color(0xFF2D2419); // Vintage book cover
  static const Color textAgedPaper = Color(0xFFE6D7C3); // Aged paper
  static const Color textSubtle = Color(0xFFD4C5B0); // Softer text
  static const Color accentGold = Color(0xFFD4AF37); // Old gold
  static const Color shadowDark = Color(0xFF0D0A08); // Deep shadow

  /// Main dark academia theme
  static ThemeData get moodyCalmTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryBrass,
      cardColor: cardVintage,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryBrass,
        secondary: accentGold,
        surface: cardVintage,
        onPrimary: textAgedPaper,
        onSecondary: backgroundDark,
        onSurface: textAgedPaper,
      ),

      // Text theme with scholarly serif fonts
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 32,
          color: textAgedPaper,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 28,
          color: textAgedPaper,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 24,
          color: textAgedPaper,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 24,
          color: textAgedPaper,
          letterSpacing: 1.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Lora',
          fontSize: 20,
          color: textAgedPaper,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Lora',
          fontSize: 18,
          color: textAgedPaper,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Lora',
          fontSize: 16,
          color: textSubtle,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Lora',
          fontSize: 14,
          color: textSubtle,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Lora',
          fontSize: 12,
          color: textSubtle,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Lora',
          fontSize: 14,
          color: textAgedPaper,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card theme
      cardTheme: const CardThemeData(
        color: cardVintage,
        elevation: 8,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: cardVintage,
        elevation: 4,
        titleTextStyle: TextStyle(
          fontFamily: 'Crimson Text',
          fontSize: 22,
          color: textAgedPaper,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: primaryBrass),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrass,
          foregroundColor: textAgedPaper,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Lora',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: primaryBrass,
        size: 24,
      ),
    );
  }
}

/// Vintage card with old paper texture effect
class VintageCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const VintageCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: DarkAcademiaTheme.cardVintage,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        // Paper texture simulation
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DarkAcademiaTheme.cardVintage,
            DarkAcademiaTheme.cardVintage.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Scholarly text with serif font and aged paper color
class ScholarlyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign? textAlign;

  const ScholarlyText({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Crimson Text',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: DarkAcademiaTheme.textAgedPaper,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Brass-colored button with vintage styling
class BrassButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final double? width;

  const BrassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkAcademiaTheme.primaryBrass,
          foregroundColor: DarkAcademiaTheme.textAgedPaper,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Old book texture background
class LibraryBackground extends StatelessWidget {
  final Widget child;
  final double opacity;

  const LibraryBackground({
    super.key,
    required this.child,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark background
        Container(color: DarkAcademiaTheme.backgroundDark),
        
        // Texture overlay
        Opacity(
          opacity: opacity,
          child: CustomPaint(
            painter: _BookTexturePainter(),
            size: Size.infinite,
          ),
        ),
        
        // Content
        child,
      ],
    );
  }
}

class _BookTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DarkAcademiaTheme.textAgedPaper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw horizontal lines like old book pages
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vintage list tile with dark academia styling
class VintageListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leading;
  final VoidCallback? onTap;
  final Widget? trailing;

  const VintageListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: VintageCard(
        padding: const EdgeInsets.all(12),
        child: ListTile(
          leading: leading != null
              ? Icon(leading, color: DarkAcademiaTheme.primaryBrass)
              : null,
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontWeight: FontWeight.w600,
              color: DarkAcademiaTheme.textAgedPaper,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    color: DarkAcademiaTheme.textSubtle,
                  ),
                )
              : null,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Brass icon button with vintage styling
class BrassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const BrassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DarkAcademiaTheme.primaryBrass.withValues(alpha: 0.2),
            border: Border.all(
              color: DarkAcademiaTheme.primaryBrass,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: DarkAcademiaTheme.primaryBrass,
            size: size,
          ),
        ),
      ),
    );
  }
}
