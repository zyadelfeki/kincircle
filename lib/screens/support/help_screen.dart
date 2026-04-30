import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../widgets/nav_shell.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<_FaqGroup> _faqGroups = <_FaqGroup>[
    _FaqGroup(
      category: 'Safety & Alerts',
      entries: [
        _FaqEntry(
          question: 'How do SOS alerts work in KinCircle?',
          answer:
              'SOS sends an urgent alert to your circle and opens emergency quick actions so members can react immediately.',
        ),
        _FaqEntry(
          question: 'Why am I not receiving alerts?',
          answer:
              'Check app notification permissions and ensure Push Notifications is enabled in Settings > Notifications.',
        ),
      ],
    ),
    _FaqGroup(
      category: 'Location',
      entries: [
        _FaqEntry(
          question: 'How often is location updated?',
          answer:
              'Location updates are sent automatically when movement is detected and permissions are granted.',
        ),
        _FaqEntry(
          question: 'Can I pause location sharing?',
          answer:
              'Yes. Go to Settings > Privacy and turn off Location sharing. You can re-enable anytime.',
        ),
      ],
    ),
    _FaqGroup(
      category: 'Circle & Invites',
      entries: [
        _FaqEntry(
          question: 'How do I invite family members?',
          answer:
              'Open Invite screen and share your invite link, code, or send via SMS/WhatsApp.',
        ),
        _FaqEntry(
          question: 'Can I join using only an invite code?',
          answer:
              'Yes. Use the Join with Code flow from create-family empty state or from invite tools.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqGroup> _filteredGroups() {
    if (_query.trim().isEmpty) return _faqGroups;
    final String q = _query.toLowerCase();
    return _faqGroups
        .map((_FaqGroup group) {
          final List<_FaqEntry> entries = group.entries.where((_FaqEntry entry) {
            return entry.question.toLowerCase().contains(q) ||
                entry.answer.toLowerCase().contains(q) ||
                group.category.toLowerCase().contains(q);
          }).toList();
          return _FaqGroup(category: group.category, entries: entries);
        })
        .where((_FaqGroup group) => group.entries.isNotEmpty)
        .toList();
  }

  Future<void> _launchEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@kincircle.app',
      query: 'subject=KinCircle Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email client unavailable')),
    );
  }

  Future<void> _launchChat() async {
    final Uri uri = Uri.parse('https://wa.me/201000000000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat support unavailable')),
    );
  }

  Future<void> _launchStore() async {
    // TODO: replace with real App Store / Play Store URL.
    final Uri uri = Uri.parse('https://play.google.com/store/apps/details?id=com.example.kincircle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store link unavailable')),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: KinCircleDecorations.input(),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) {
          setState(() => _query = value);
        },
        style: KinCircleTypography.body14(),
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: KinCirclePalette.of(context).textMuted),
          hintText: 'Search help articles',
          hintStyle: KinCircleTypography.body14(color: KinCirclePalette.of(context).textMuted),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _faqList() {
    final palette = KinCirclePalette.of(context);
    final List<_FaqGroup> groups = _filteredGroups();
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              Icon(Icons.search_off, color: palette.textMuted, size: 40),
              const SizedBox(height: 8),
              Text(
                'No FAQ matches your search',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((_FaqGroup group) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: KinCircleDecorations.card(),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                group.category,
                style: KinCircleTypography.body14(weight: FontWeight.w600),
              ),
              iconColor: palette.accent,
              collapsedIconColor: palette.textMuted,
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: group.entries.map((_FaqEntry entry) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.question,
                          style: KinCircleTypography.body14(weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.answer,
                          style: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _contactSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: KinCircleDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact Support', style: KinCircleTypography.cardTitle16()),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _launchEmail,
            style: KinCircleButtons.primary(),
            child: const Text('Email Support'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _launchChat,
            style: KinCircleButtons.secondary(),
            child: const Text('Chat Support'),
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: _launchStore,
            leading: const Icon(Icons.star_rate_rounded, color: KinCirclePalette.accent),
            title: Text(
              'Rate the app',
              style: KinCircleTypography.body14(weight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: KinCirclePalette.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 4,
      title: 'Help & Support',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _searchBar(),
          _faqList(),
          _contactSection(),
        ],
      ),
    );
  }
}

class _FaqGroup {
  const _FaqGroup({
    required this.category,
    required this.entries,
  });

  final String category;
  final List<_FaqEntry> entries;
}

class _FaqEntry {
  const _FaqEntry({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
