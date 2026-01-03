import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==============================
// KinCircle Design System Theme
// ==============================

// 1) Color Scheme tokens
const Color kinPrimary = Color(0xFF2E86AB); // Trust Blue
const Color kinOnPrimary = Color(0xFFFFFFFF); // Neutral White
const Color kinSecondary = Color(0xFF10B981); // Accent Green
const Color kinOnSecondary = Color(0xFFFFFFFF); // Neutral White
const Color kinError = Color(0xFFE53935); // SOS Red
const Color kinOnError = Color(0xFFFFFFFF); // Neutral White
const Color kinBackground = Color(0xFFFFFFFF); // Neutral White
const Color kinOnBackground = Color(0xFF0F172A); // Neutral Dark
const Color kinSurface = Color(0xFFF8FAFC); // Neutral Off-White
const Color kinOnSurface = Color(0xFF0F172A); // Neutral Dark
const Color kinSurfaceVariant = Color(0xFFE2E8F0); // Neutral Border
const Color kinOnSurfaceVariant = Color(0xFF64748B); // Neutral Grey
const Color kinOutline = Color(0xFFE2E8F0); // Neutral Border

// Pro accent (used when subscription is active)
const Color kinProAccent = Color(0xFFFFB300); // Premium Gold
const Color kinProTeal = Color(0xFF0FB5A9);   // Premium Teal
const Color kinProNavy = Color(0xFF0A1224);   // Deep Navy for Pro light bg

// Dark palette bases
const Color kinDarkBackground = Color(0xFF0B1220);
const Color kinDarkSurface = Color(0xFF0F172A);
const Color kinDarkOnSurface = Color(0xFFE2E8F0);
const Color kinDarkOnSurfaceVariant = Color(0xFF94A3B8);

ColorScheme _buildColorScheme({
  required Brightness brightness,
  required bool pro,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: kinPrimary,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return base.copyWith(
    primary: pro ? kinProTeal : kinPrimary,
    onPrimary: kinOnPrimary,
    secondary: pro ? kinProAccent : kinSecondary,
    onSecondary: kinOnSecondary,
    error: kinError,
    onError: kinOnError,
  surface: isDark ? kinDarkSurface : (pro ? kinProNavy : kinSurface),
  onSurface: isDark ? kinDarkOnSurface : (pro ? Colors.white70 : kinOnSurface),
    onSurfaceVariant: isDark ? kinDarkOnSurfaceVariant : kinOnSurfaceVariant,
    outline: isDark ? const Color(0xFF1F2937) : kinOutline,
  );
}

// 2) Typography using GoogleFonts Inter
final TextTheme kinCircleTextTheme = TextTheme(
  // displaySmall (H1): 28pt, Bold (700), #0F172A
  displaySmall: GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    // color assigned later via apply with current scheme
    height: 1.2,
  ),
  // headlineMedium (H2): 22pt, Bold (700), #0F172A
  headlineMedium: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    // deferred to scheme
    height: 1.25,
  ),
  // titleMedium (Subtitle): 16pt, Semi-Bold (600), #0F172A
  titleMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    // deferred to scheme
    height: 1.3,
  ),
  // bodyLarge (Body): 16pt, Regular (400), #0F172A
  bodyLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    // deferred to scheme
    height: 1.45,
  ),
  // bodySmall (Caption): 12pt, Regular (400), #64748B
  bodySmall: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    // deferred to scheme
    height: 1.4,
  ),
  // labelLarge (Button Text): 16pt, Bold (700)
  labelLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    // uses onPrimary
    height: 1.3,
  ),
);

// 3) Component Themes
ElevatedButtonThemeData _kinElevatedButtonTheme(ColorScheme scheme) =>
    ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24),
        ),
        backgroundColor: WidgetStatePropertyAll(scheme.primary),
        foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

OutlinedButtonThemeData _kinOutlinedButtonTheme(ColorScheme scheme) =>
    OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        foregroundColor: WidgetStatePropertyAll(scheme.primary),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.primary, width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
      ),
    );

TextButtonThemeData _kinTextButtonTheme(ColorScheme scheme) =>
    TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        foregroundColor: WidgetStatePropertyAll(scheme.primary),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
      ),
    );

InputDecorationTheme _kinInputDecorationTheme(ColorScheme scheme) =>
    InputDecorationTheme(
      filled: true,
      fillColor:
          scheme.brightness == Brightness.dark ? kinDarkSurface : kinBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kinError, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kinError, width: 2),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
    );

CardThemeData _kinCardTheme(ColorScheme scheme) => CardThemeData(
      color: scheme.brightness == Brightness.dark ? kinDarkSurface : kinSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
    );

BottomNavigationBarThemeData _kinBottomNavTheme(ColorScheme scheme) =>
    BottomNavigationBarThemeData(
      backgroundColor:
          scheme.brightness == Brightness.dark ? kinDarkSurface : kinBackground,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );

// 4) Theme builder (supports brightness + Pro accent)
ThemeData kinTheme(
    {Brightness brightness = Brightness.light, bool pro = false}) {
  final scheme = _buildColorScheme(brightness: brightness, pro: pro);
  final isDark = brightness == Brightness.dark;
  // Apply high-contrast colors from scheme to text theme
  final appliedTextTheme = kinCircleTextTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? kinDarkBackground : (pro ? kinProNavy : kinBackground),
    textTheme: appliedTextTheme,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    }),
    elevatedButtonTheme: _kinElevatedButtonTheme(scheme),
    outlinedButtonTheme: _kinOutlinedButtonTheme(scheme),
    textButtonTheme: _kinTextButtonTheme(scheme),
    inputDecorationTheme: _kinInputDecorationTheme(scheme),
    cardTheme: _kinCardTheme(scheme),
    bottomNavigationBarTheme: _kinBottomNavTheme(scheme),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? kinDarkBackground : (pro ? kinProNavy : kinBackground),
      foregroundColor: isDark ? Colors.white : (pro ? Colors.white : kinOnBackground),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: appliedTextTheme.titleMedium,
      iconTheme:
          IconThemeData(color: isDark ? Colors.white : kinOnBackground),
    ),
    dividerColor: scheme.outline,
    dividerTheme: DividerThemeData(color: scheme.outline),
  );
}

// Public presets
final ThemeData kinCircleTheme = kinTheme(brightness: Brightness.light);
final ThemeData kinCircleDarkTheme = kinTheme(brightness: Brightness.dark);

// ---------------------------------------------
// Backward-compat layer for existing references
// ---------------------------------------------
class AppTheme {
  // Preserve legacy names while aligning to new palette
  static const Color primaryBlue = kinPrimary;
  static const Color accentGreen = kinSecondary;
  static const Color sosRed = kinError;

  static final ThemeData lightTheme = kinCircleTheme;
  static final ThemeData darkTheme = kinCircleDarkTheme;
}
