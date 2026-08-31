import 'package:flutter/material.dart';

import '../design/kincircle_screen_tokens.dart';
import '../models/user_model.dart';
import '../services/member_timeline_service.dart';
import '../utils/time_utils.dart';
import '../widgets/dashboard/two_row_skeleton.dart';

class MemberTimelineScreen extends StatefulWidget {
  const MemberTimelineScreen({
    super.key,
    required this.member,
    required this.familyId,
    this.timelineProvider,
  });

  final AppUser member;
  final String familyId;
  final Future<List<TimelineEvent>> Function({
    required String uid,
    required String familyId,
  })? timelineProvider;

  @override
  State<MemberTimelineScreen> createState() => _MemberTimelineScreenState();
}

class _MemberTimelineScreenState extends State<MemberTimelineScreen> {
  late Future<List<TimelineEvent>> _timelineFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final provider = widget.timelineProvider ?? MemberTimelineService.getMemberTimeline;
    setState(() {
      _timelineFuture = provider(
        uid: widget.member.uid,
        familyId: widget.familyId,
      );
    });
  }

  String _firstName(String displayName) {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Member';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Color _dotColor(String type, KinCirclePaletteData palette) {
    final String lower = type.toLowerCase();
    if (lower == 'checkin') return palette.success;
    if (lower == 'sos') return palette.error;
    if (lower == 'streak') return palette.warning;
    return palette.accent;
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final String firstName = _firstName(widget.member.displayName);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          "$firstName's today",
          style: KinCircleTypography.cardTitle16(
            color: palette.textPrimary,
            weight: FontWeight.w700,
          ),
        ),
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<List<TimelineEvent>>(
        future: _timelineFuture,
        builder: (BuildContext context, AsyncSnapshot<List<TimelineEvent>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading(palette);
          }

          if (snapshot.hasError) {
            return _buildError(palette);
          }

          final List<TimelineEvent> events = snapshot.data ?? <TimelineEvent>[];
          if (events.isEmpty) {
            return _buildEmpty(palette);
          }

          return _buildTimelineList(events, palette);
        },
      ),
    );
  }

  Widget _buildLoading(KinCirclePaletteData palette) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: KinCircleRadii.card,
          border: Border.all(color: palette.border),
        ),
        child: const TwoRowSkeleton(),
      ),
    );
  }

  Widget _buildError(KinCirclePaletteData palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: palette.error),
            const SizedBox(height: 16),
            Text(
              "Couldn't load today's activity",
              style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: KinCircleButtons.primary(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(KinCirclePaletteData palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 48, color: palette.textMuted),
            const SizedBox(height: 16),
            Text(
              'No activity yet today',
              style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check-ins, alerts and place visits will show here',
              style: KinCircleTypography.body14(color: palette.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList(List<TimelineEvent> events, KinCirclePaletteData palette) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: events.length,
      itemBuilder: (BuildContext context, int index) {
        final TimelineEvent event = events[index];
        final bool isFirst = index == 0;
        final bool isLast = index == events.length - 1;
        final Color dotColor = _dotColor(event.type, palette);
        final String timeLabel = formatRelativeTime(event.timestamp);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left rail with dot and 2px line
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    // Top line
                    Container(
                      width: 2,
                      height: 8,
                      color: isFirst ? Colors.transparent : palette.border,
                    ),
                    // 12px Dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Bottom line
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : palette.border,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (event.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.subtitle,
                          style: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        timeLabel,
                        style: KinCircleTypography.caption12(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
