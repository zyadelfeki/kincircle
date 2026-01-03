import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/companion_service.dart';

/// Companion avatar with breathing animation
class CompanionAvatar extends StatefulWidget {
  final CompanionPersonality personality;
  final double size;
  final bool animated;
  final VoidCallback? onTap;

  const CompanionAvatar({
    super.key,
    required this.personality,
    this.size = 60,
    this.animated = true,
    this.onTap,
  });

  @override
  State<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat(reverse: true);

      _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = CompanionProfile.forPersonality(widget.personality);
    
    Widget avatar = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getGradientForPersonality(),
          boxShadow: [
            BoxShadow(
              color: _getColorForPersonality().withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            profile.avatar,
            style: TextStyle(fontSize: widget.size * 0.5),
          ),
        ),
      ),
    );

    if (widget.animated) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: avatar,
      );
    }

    return avatar;
  }

  LinearGradient _getGradientForPersonality() {
    switch (widget.personality) {
      case CompanionPersonality.sage:
        return LinearGradient(
          colors: [Colors.purple.shade300, Colors.purple.shade600],
        );
      case CompanionPersonality.spark:
        return LinearGradient(
          colors: [Colors.orange.shade300, Colors.red.shade500],
        );
      case CompanionPersonality.grove:
        return LinearGradient(
          colors: [Colors.green.shade300, Colors.teal.shade600],
        );
      case CompanionPersonality.echo:
        return LinearGradient(
          colors: [Colors.blue.shade300, Colors.indigo.shade600],
        );
    }
  }

  Color _getColorForPersonality() {
    switch (widget.personality) {
      case CompanionPersonality.sage:
        return Colors.purple;
      case CompanionPersonality.spark:
        return Colors.orange;
      case CompanionPersonality.grove:
        return Colors.green;
      case CompanionPersonality.echo:
        return Colors.blue;
    }
  }
}

/// Companion message bubble
class CompanionMessageBubble extends StatefulWidget {
  final String message;
  final CompanionPersonality personality;
  final bool autoDismiss;

  const CompanionMessageBubble({
    super.key,
    required this.message,
    required this.personality,
    this.autoDismiss = true,
  });

  @override
  State<CompanionMessageBubble> createState() => _CompanionMessageBubbleState();
}

class _CompanionMessageBubbleState extends State<CompanionMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    if (widget.autoDismiss) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          _controller.reverse();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _getColorForPersonality().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getColorForPersonality().withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionAvatar(
                personality: widget.personality,
                size: 40,
                animated: false,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontFamily: 'Lora',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForPersonality() {
    switch (widget.personality) {
      case CompanionPersonality.sage:
        return Colors.purple;
      case CompanionPersonality.spark:
        return Colors.orange;
      case CompanionPersonality.grove:
        return Colors.green;
      case CompanionPersonality.echo:
        return Colors.blue;
    }
  }
}

/// Companion dashboard widget
class CompanionDashboardWidget extends StatelessWidget {
  const CompanionDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CompanionService>(
      builder: (context, companion, _) {
        final message = companion.getGreeting();
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CompanionAvatar(
                personality: companion.personality,
                size: 50,
                onTap: () {
                  companion.recordInteraction();
                  _showCompanionMessage(context, companion);
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companion.profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildRelationshipBar(companion.relationshipScore),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelationshipBar(int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, size: 12, color: Colors.pink),
            const SizedBox(width: 4),
            Text(
              'Bond: $score/100',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  void _showCompanionMessage(BuildContext context, CompanionService companion) {
    final encouragement = companion.getEncouragement();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionAvatar(
                personality: companion.personality,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                companion.profile.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                encouragement,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Lora',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Thanks!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Companion selection screen
class CompanionSelectionScreen extends StatelessWidget {
  const CompanionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Companion'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Your companion will be with you throughout your journey, offering support and celebrating your achievements.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildPersonalityCard(
                    context,
                    CompanionPersonality.sage,
                    'Sage',
                    '🧙',
                    'Wise and calming',
                    'Perfect for those seeking wisdom and tranquility',
                    Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  _buildPersonalityCard(
                    context,
                    CompanionPersonality.spark,
                    'Spark',
                    '⚡',
                    'Energetic motivator',
                    'Great for staying motivated and energized',
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildPersonalityCard(
                    context,
                    CompanionPersonality.grove,
                    'Grove',
                    '🌿',
                    'Nature-loving guide',
                    'Ideal for finding peace and natural harmony',
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildPersonalityCard(
                    context,
                    CompanionPersonality.echo,
                    'Echo',
                    '💙',
                    'Understanding listener',
                    'Best for empathy and emotional support',
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalityCard(
    BuildContext context,
    CompanionPersonality personality,
    String name,
    String avatar,
    String tagline,
    String description,
    MaterialColor color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _selectCompanion(context, personality),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color[300]!, color[600]!],
                  ),
                ),
                child: Center(
                  child: Text(avatar, style: const TextStyle(fontSize: 35)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tagline,
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCompanion(
    BuildContext context,
    CompanionPersonality personality,
  ) async {
    final companion = Provider.of<CompanionService>(context, listen: false);
    await companion.selectPersonality(personality);

    if (context.mounted) {
      // Show welcome message
      final profile = CompanionProfile.forPersonality(personality);
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompanionAvatar(
                  personality: personality,
                  size: 100,
                ),
                const SizedBox(height: 16),
                Text(
                  'Meet ${profile.name}!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.greetingMessages[0],
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Lora',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Start Journey'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
