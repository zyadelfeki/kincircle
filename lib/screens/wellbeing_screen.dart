import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/kincircle_screen_tokens.dart';
import '../services/recommendation_engine.dart';
import '../services/trend_analysis_service.dart';
import '../services/wellbeing_analytics_service.dart';
import '../widgets/nav_shell.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  bool _loading = true;
  String? _error;
  WellbeingMetrics? _metrics;
  List<Recommendation> _recommendations = <Recommendation>[];
  List<Insight> _insights = <Insight>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in to view wellbeing insights.';
        });
        return;
      }

      final WellbeingAnalyticsService analytics = WellbeingAnalyticsService();
      final WellbeingMetrics metrics = await analytics.calculateMetrics(uid);
      final List<Recommendation> recs = await RecommendationEngine.generate(uid);
      final List<Insight> insights = await TrendAnalysisService.analyze(uid);
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _recommendations = recs;
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load wellbeing data.';
      });
    }
  }



  Widget _loadingView() {
    final palette = KinCirclePalette.of(context);
    return ListView(
      children: [
        const SizedBox(height: 12),
        ...List<Widget>.generate(4, (int _) {
          return Shimmer.fromColors(
            baseColor: palette.surfaceAlt,
            highlightColor: palette.border,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              height: 110,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _errorView() {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 50, color: palette.error),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Error',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard() {
    final palette = KinCirclePalette.of(context);
    final WellbeingMetrics metrics = _metrics!;
    final int score = metrics.overallScore.round().clamp(0, 100);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: KinCircleDecorations.card(
        color: palette.cardSurface,
        borderColor: palette.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Wellbeing',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '$score%',
            style: KinCircleTypography.heading22(color: palette.accent),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: palette.surfaceAlt,
            color: palette.accent,
          ),
          const SizedBox(height: 10),
          Text(
            'Stress: ${metrics.stressLevel.name} • Activity: ${metrics.activityLevel.toStringAsFixed(0)}%',
            style: KinCircleTypography.caption12(color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _recommendationsCard() {
    final palette = KinCirclePalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: KinCircleDecorations.card(
        color: palette.cardSurface,
        borderColor: palette.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommendations',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          if (_recommendations.isEmpty)
            Text(
              'No recommendations yet.',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            )
          else
            ..._recommendations.take(4).map((Recommendation rec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(rec.icon, color: palette.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec.title,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rec.estimatedTime,
                        style: KinCircleTypography.caption12(color: palette.textMuted),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _insightsCard() {
    final palette = KinCirclePalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      padding: const EdgeInsets.all(14),
      decoration: KinCircleDecorations.card(
        color: palette.cardSurface,
        borderColor: palette.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          if (_insights.isEmpty)
            Text(
              'No trend insights yet.',
              style: KinCircleTypography.caption12(color: palette.textMuted),
            )
          else
            ..._insights.take(4).map((Insight insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight.icon, color: palette.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: KinCircleTypography.body14(
                              color: palette.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.description,
                            style: KinCircleTypography.caption12(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();
    return ListView(
      children: [
        _scoreCard(),
        _recommendationsCard(),
        _insightsCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 4,
      title: 'Wellbeing',
      body: _content(),
    );
  }
}
