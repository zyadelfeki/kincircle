import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==============================
// KinCircle Design System Theme
// ==============================

// 1) Color Scheme tokens
const Color kinPrimary = Color(0xFF1976D2); // Primary Blue
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

final ColorScheme kinCircleColorScheme = ColorScheme.fromSeed(
  seedColor: kinPrimary,
  brightness: Brightness.light,
).copyWith(
  primary: kinPrimary,
  onPrimary: kinOnPrimary,
  secondary: kinSecondary,
  onSecondary: kinOnSecondary,
  error: kinError,
  onError: kinOnError,
  surface: kinSurface,
  onSurface: kinOnSurface,
  // Use modern fields only; avoid deprecated background/onBackground/surfaceVariant
  onSurfaceVariant: kinOnSurfaceVariant,
  outline: kinOutline,
);

// 2) Typography using GoogleFonts Inter
final TextTheme kinCircleTextTheme = TextTheme(
  // displaySmall (H1): 28pt, Bold (700), #0F172A
  displaySmall: GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: kinOnBackground,
    height: 1.2,
  ),
  // headlineMedium (H2): 22pt, Bold (700), #0F172A
  headlineMedium: GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: kinOnBackground,
    height: 1.25,
  ),
  // titleMedium (Subtitle): 16pt, Semi-Bold (600), #0F172A
  titleMedium: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: kinOnBackground,
    height: 1.3,
  ),
  // bodyLarge (Body): 16pt, Regular (400), #0F172A
  bodyLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: kinOnBackground,
    height: 1.45,
  ),
  // bodySmall (Caption): 12pt, Regular (400), #64748B
  bodySmall: GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: kinOnSurfaceVariant,
    height: 1.4,
  ),
  // labelLarge (Button Text): 16pt, Bold (700)
  labelLarge: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: kinOnPrimary,
    height: 1.3,
  ),
);

// 3) Component Themes
final ElevatedButtonThemeData _kinElevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
  padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24),
    ),
  backgroundColor: const WidgetStatePropertyAll(kinPrimary),
  foregroundColor: const WidgetStatePropertyAll(kinOnPrimary),
  textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
  shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);

final OutlinedButtonThemeData _kinOutlinedButtonTheme =
    OutlinedButtonThemeData(
  style: ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
  foregroundColor: const WidgetStatePropertyAll(kinPrimary),
  side: const WidgetStatePropertyAll(
      BorderSide(color: kinPrimary, width: 1),
    ),
  shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
  ),
);

final TextButtonThemeData _kinTextButtonTheme = TextButtonThemeData(
  style: ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
  foregroundColor: const WidgetStatePropertyAll(kinPrimary),
  shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  textStyle: WidgetStatePropertyAll(kinCircleTextTheme.labelLarge),
  ),
);

final InputDecorationTheme _kinInputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: kinBackground,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kinOutline, width: 1),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kinOutline, width: 1),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kinPrimary, width: 2),
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
    color: kinOnSurfaceVariant,
  ),
  labelStyle: GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: kinOnSurfaceVariant,
  ),
);

final CardThemeData _kinCardTheme = CardThemeData(
  color: kinSurface,
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.all(8),
);

const BottomNavigationBarThemeData _kinBottomNavTheme =
  BottomNavigationBarThemeData(
  backgroundColor: kinBackground,
  selectedItemColor: kinPrimary,
  unselectedItemColor: kinOnSurfaceVariant,
  type: BottomNavigationBarType.fixed,
  elevation: 8,
);

// 4) Final ThemeData
final ThemeData kinCircleTheme = ThemeData(
  useMaterial3: true,
  colorScheme: kinCircleColorScheme,
  scaffoldBackgroundColor: kinBackground,
  textTheme: kinCircleTextTheme,
  elevatedButtonTheme: _kinElevatedButtonTheme,
  outlinedButtonTheme: _kinOutlinedButtonTheme,
  textButtonTheme: _kinTextButtonTheme,
  inputDecorationTheme: _kinInputDecorationTheme,
  cardTheme: _kinCardTheme,
  bottomNavigationBarTheme: _kinBottomNavTheme,
  appBarTheme: AppBarTheme(
    backgroundColor: kinBackground,
    foregroundColor: kinOnBackground,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: kinCircleTextTheme.titleMedium,
    iconTheme: const IconThemeData(color: kinOnBackground),
  ),
  dividerColor: kinOutline,
  dividerTheme: const DividerThemeData(color: kinOutline),
);

// ---------------------------------------------
// Backward-compat layer for existing references
// ---------------------------------------------
class AppTheme {
  // Preserve legacy names while aligning to new palette
  static const Color primaryBlue = kinPrimary;
  static const Color accentGreen = kinSecondary;
  static const Color sosRed = kinError;

  static final ThemeData lightTheme = kinCircleTheme;
}
