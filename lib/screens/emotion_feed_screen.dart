import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/social_contagion_service.dart';
import '../services/companion_service.dart';
import '../widgets/celebration_widgets.dart';

/// Community emotion feed screen
class EmotionFeedScreen extends StatefulWidget {
  const EmotionFeedScreen({super.key});

  @override
  State<EmotionFeedScreen> createState() => _EmotionFeedScreenState();
}

class _EmotionFeedScreenState extends State<EmotionFeedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Moments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () => _showResearchInfo(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Consumer<SocialContagionService>(
          builder: (context, social, _) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community')
                  .doc('positive_events')
                  .collection('recent')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data?.docs ?? [];

                if (events.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(social),
                      const SizedBox(height: 48),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.favorite_border,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No community moments yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share positivity!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildHeader(social);
                    }

                    final event = events[index - 1];
                    return _buildEventCard(event);
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sharePositivity(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Share Positivity'),
      ),
    );
  }

  Widget _buildHeader(SocialContagionService social) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.pink.shade300,
                Colors.purple.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.favorite,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Community Positivity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community')
                    .doc('stats')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white70),
                    );
                  }

                  final stats = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final activeToday = stats['activeToday'] ?? 0;
                  final checkInsToday = stats['checkInsToday'] ?? 0;
                  
                  return Column(
                    children: [
                      Text(
                        '$activeToday families active today',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$checkInsToday positive moments shared',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildQuickActions(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickActionButton(
          icon: Icons.celebration,
          label: 'Celebrate',
          color: Colors.orange,
          onTap: () => _quickCelebration(context),
        ),
        _buildQuickActionButton(
          icon: Icons.emoji_emotions,
          label: 'Share Joy',
          color: Colors.yellow.shade700,
          onTap: () => _quickJoyShare(context),
        ),
        _buildQuickActionButton(
          icon: Icons.volunteer_activism,
          label: 'Support',
          color: Colors.pink,
          onTap: () => _quickSupport(context),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot event) {
    final data = event.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'unknown';
    final message = data['message'] as String? ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final reactions = data['reactions'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _getIconForEventType(type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Lora',
                    ),
                    maxLines: 4,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: _buildReactionBar(event.id, reactions),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getIconForEventType(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'check_in':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'milestone':
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      case 'support':
        icon = Icons.favorite;
        color = Colors.pink;
        break;
      case 'achievement':
        icon = Icons.star;
        color = Colors.purple;
        break;
      default:
        icon = Icons.auto_awesome;
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildReactionBar(String eventId, Map<String, dynamic> reactions) {
    final emojis = ['❤️', '👏', '🎉', '💪', '🌟'];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: emojis.map((emoji) {
        final count = reactions[emoji] as int? ?? 0;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            onTap: () => _addReaction(eventId, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0 ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  Future<void> _handleRefresh() async {
    // Simulate refresh delay
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feed refreshed!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sharePositivity(BuildContext context) async {
    final social = Provider.of<SocialContagionService>(context, listen: false);
    final companion = Provider.of<CompanionService>(context, listen: false);

    final result = await social.spreadPositivity('check-in completed');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: CelebrationBanner(
            message: result['message'],
            icon: Icons.favorite,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
        ),
      );

      // Companion celebration
      final celebration = companion.getCelebration();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${companion.profile.name}: $celebration'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _quickCelebration(BuildContext context) async {
    await _addPositiveEvent('celebration', 'Someone is celebrating a win! 🎉');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Celebration shared!')),
      );
    }
  }

  Future<void> _quickJoyShare(BuildContext context) async {
    await _addPositiveEvent('joy', 'Someone is spreading joy today! 😊');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joy shared!')),
      );
    }
  }

  Future<void> _quickSupport(BuildContext context) async {
    await _addPositiveEvent('support', 'Someone sent out support! 💕');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support sent!')),
      );
    }
  }

  Future<void> _addPositiveEvent(String type, String message) async {
    await FirebaseFirestore.instance
        .collection('community')
        .doc('positive_events')
        .collection('recent')
        .add({
      'type': type,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });
  }

  Future<void> _addReaction(String eventId, String emoji) async {
    await FirebaseFirestore.instance
        .collection('community')
        .doc('positive_events')
        .collection('recent')
        .doc(eventId)
        .update({
      'reactions.$emoji': FieldValue.increment(1),
    });
  }

  void _showResearchInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(child: Text('Research-Backed')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Emotional Contagion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Research with 689,003 Facebook users found that emotional states spread through social networks.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                'Key Findings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Positive content increases positive posts by 15%'),
              Text('• Emotional support spreads through communities'),
              Text('• Anonymized sharing reduces social anxiety'),
              SizedBox(height: 12),
              Text(
                'This feed is designed to spread positivity while protecting privacy.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
