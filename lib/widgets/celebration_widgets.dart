import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Particle for confetti explosion
class Particle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  double rotation;
  double rotationSpeed;
  double life;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    this.life = 1.0,
  });
}

/// Confetti particle explosion widget
class ParticleExplosion extends StatefulWidget {
  final int particleCount;
  final List<Color> colors;
  final Duration duration;
  final VoidCallback? onComplete;

  const ParticleExplosion({
    super.key,
    this.particleCount = 50,
    this.colors = const [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ],
    this.duration = const Duration(seconds: 3),
    this.onComplete,
  });

  @override
  State<ParticleExplosion> createState() => _ParticleExplosionState();
}

class _ParticleExplosionState extends State<ParticleExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];
  final random = math.Random();

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..addListener(() {
        _updateParticles();
      });

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  void _initializeParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      final angle = (i / widget.particleCount) * 2 * math.pi;
      final speed = 100 + random.nextDouble() * 200;
      
      particles.add(Particle(
        position: const Offset(0, 0),
        velocity: Offset(
          math.cos(angle) * speed,
          math.sin(angle) * speed - 50, // Slight upward bias
        ),
        color: widget.colors[random.nextInt(widget.colors.length)],
        size: 4 + random.nextDouble() * 8,
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 10,
      ));
    }
  }

  void _updateParticles() {
    setState(() {
      final dt = 0.016; // ~60fps
      for (var particle in particles) {
        // Update position
        particle.position += particle.velocity * dt;
        
        // Apply gravity
        particle.velocity = Offset(
          particle.velocity.dx,
          particle.velocity.dy + 400 * dt, // Gravity
        );
        
        // Update rotation
        particle.rotation += particle.rotationSpeed * dt;
        
        // Fade out
        particle.life = 1.0 - _controller.value;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(particles),
      size: Size.infinite,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life)
        ..style = PaintingStyle.fill;

      canvas.save();
      final pos = center + particle.position;
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(particle.rotation);
      
      // Draw confetti piece (rectangle)
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 2,
        ),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Community celebration dialog
class CommunityCelebrationDialog extends StatefulWidget {
  final String achievement;
  final int communityCount;
  final String socialProof;
  final String? companionMessage;

  const CommunityCelebrationDialog({
    super.key,
    required this.achievement,
    required this.communityCount,
    required this.socialProof,
    this.companionMessage,
  });

  @override
  State<CommunityCelebrationDialog> createState() =>
      _CommunityCelebrationDialogState();
}

class _CommunityCelebrationDialogState
    extends State<CommunityCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<int> _counterAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _counterAnimation = IntTween(begin: 0, end: widget.communityCount).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti background
          const Positioned.fill(
            child: ParticleExplosion(
              particleCount: 80,
            ),
          ),
          
          // Content
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Achievement icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.celebration,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Achievement text
                    Text(
                      widget.achievement,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Community count
                    AnimatedBuilder(
                      animation: _counterAnimation,
                      builder: (context, child) {
                        return Text(
                          '${_counterAnimation.value}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [Colors.purple, Colors.blue],
                              ).createShader(
                                const Rect.fromLTWH(0, 0, 200, 70),
                              ),
                          ),
                        );
                      },
                    ),
                    
                    Text(
                      widget.socialProof,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    
                    // Companion message if provided
                    if (widget.companionMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.companionMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Close button
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Awesome!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievement wave animation showing community participation
class AchievementWave extends StatefulWidget {
  final int participantCount;
  final Duration duration;

  const AchievementWave({
    super.key,
    required this.participantCount,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AchievementWave> createState() => _AchievementWaveState();
}

class _AchievementWaveState extends State<AchievementWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            progress: _controller.value,
            participantCount: widget.participantCount,
          ),
          size: const Size(300, 300),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final int participantCount;

  _WavePainter({required this.progress, required this.participantCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple ripple waves
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress - (i * 0.2)).clamp(0.0, 1.0);
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.5;

      final paint = Paint()
        ..color = Colors.blue.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(center, radius, paint);
    }

    // Draw participant avatars around the wave
    final displayCount = (participantCount * progress).toInt().clamp(0, 12);
    for (int i = 0; i < displayCount; i++) {
      final angle = (i / 12) * 2 * math.pi;
      final radius = maxRadius * 0.8;
      final pos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      final avatarPaint = Paint()
        ..color = Colors.purple.shade300
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pos, 12, avatarPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Simple celebration banner
class CelebrationBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const CelebrationBanner({
    super.key,
    required this.message,
    this.icon = Icons.celebration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
