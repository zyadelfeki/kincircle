import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              SizedBox(
                width: 180,
                height: 120,
                child: CustomPaint(
                  painter:
                      _InterlockingRingsPainter(color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'KinCircle',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Know your family is safe.',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  '/auth',
                  arguments: {'mode': 'login'},
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(
                  'Log In',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '© 2024 KinCircle Inc. All rights reserved. By continuing, you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterlockingRingsPainter extends CustomPainter {
  const _InterlockingRingsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..isAntiAlias = true;

    const radius = 40.0;
    final centerY = size.height / 2;
    final leftCenter = Offset(size.width * 0.42, centerY);
    final rightCenter = Offset(size.width * 0.58, centerY);

    canvas.drawCircle(leftCenter, radius, paint);
    canvas.drawCircle(rightCenter, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _InterlockingRingsPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
