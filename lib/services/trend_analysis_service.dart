import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'wellbeing_analytics_service.dart';

/// Trend analysis and pattern detection service
class TrendAnalysisService {
  /// Analyze wellbeing trends and generate insights
  static Future<List<Insight>> analyze(String userId) async {
    final history =
        await WellbeingAnalyticsService().getHistory(userId, days: 30);

    if (history.length < 7) {
      return []; // Need at least 7 days of data
    }

    final insights = <Insight>[];

    // STRESS TREND ANALYSIS
    final stressTrend =
        _calculateTrend(history.map((h) => h.stressScore).toList());

    if (stressTrend > 0.2) {
      insights.add(Insight(
        type: InsightType.warning,
        title: 'Stress Increasing',
        description:
            'Your stress has increased ${(stressTrend * 100).toInt()}% this week',
        suggestion:
            'Consider taking regular breaks and connecting with family',
        severity: Severity.high,
        icon: Icons.warning_amber,
      ));
    } else if (stressTrend < -0.2) {
      insights.add(Insight(
        type: InsightType.positive,
        title: 'Stress Decreasing!',
        description:
            'Your stress has dropped ${(-stressTrend * 100).toInt()}%',
        suggestion: 'Keep up the healthy habits!',
        severity: Severity.info,
        icon: Icons.trending_down,
      ));
    }

    // ACTIVITY TREND ANALYSIS
    final activityTrend =
        _calculateTrend(history.map((h) => h.activityLevel).toList());

    if (activityTrend > 0.15) {
      insights.add(Insight(
        type: InsightType.positive,
        title: 'Activity Improving!',
        description:
            'You\'ve been ${(activityTrend * 100).toInt()}% more active',
        suggestion: 'Keep up the great work! Try setting a new goal',
        severity: Severity.info,
        icon: Icons.trending_up,
      ));
    } else if (activityTrend < -0.15) {
      insights.add(Insight(
        type: InsightType.warning,
        title: 'Activity Declining',
        description:
            'Activity down ${(-activityTrend * 100).toInt()}% this week',
        suggestion: 'Try a 10-minute walk to restart your momentum',
        severity: Severity.medium,
        icon: Icons.trending_down,
      ));
    }

    // SLEEP TREND ANALYSIS
    final sleepTrend =
        _calculateTrend(history.map((h) => h.sleepQuality).toList());

    if (sleepTrend < -0.2) {
      insights.add(Insight(
        type: InsightType.warning,
        title: 'Sleep Quality Dropping',
        description: 'Sleep quality down ${(-sleepTrend * 100).toInt()}%',
        suggestion: 'Set a consistent bedtime and limit screens before sleep',
        severity: Severity.high,
        icon: Icons.bedtime,
      ));
    }

    // SOCIAL ENGAGEMENT TREND
    final socialTrend =
        _calculateTrend(history.map((h) => h.socialEngagement).toList());

    if (socialTrend < -0.2) {
      insights.add(Insight(
        type: InsightType.suggestion,
        title: 'Social Connection Fading',
        description: 'Family check-ins down ${(-socialTrend * 100).toInt()}%',
        suggestion: 'Reach out to a family member today',
        severity: Severity.medium,
        icon: Icons.people,
      ));
    }

    // SLEEP-ACTIVITY CORRELATION
    final sleepActivityCorr = _calculateCorrelation(
      history.map((h) => h.sleepQuality).toList(),
      history.map((h) => h.activityLevel).toList(),
    );

    if (sleepActivityCorr > 0.7) {
      insights.add(Insight(
        type: InsightType.discovery,
        title: 'Sleep & Activity Connected',
        description:
            'Better sleep leads to ${((sleepActivityCorr - 0.5) * 100).toInt()}% more activity',
        suggestion: 'Prioritize sleep to boost energy levels',
        severity: Severity.info,
        icon: Icons.lightbulb,
      ));
    }

    // STRESS-SOCIAL CORRELATION
    final stressSocialCorr = _calculateCorrelation(
      history.map((h) => h.stressScore).toList(),
      history.map((h) => h.socialEngagement).toList(),
    );

    if (stressSocialCorr < -0.6) {
      // Negative correlation = more social = less stress
      insights.add(Insight(
        type: InsightType.discovery,
        title: 'Social Connection Reduces Stress',
        description:
            'Your stress drops ${((0.6 - stressSocialCorr.abs()) * 100).toInt()}% when you connect',
        suggestion: 'Schedule regular family time',
        severity: Severity.info,
        icon: Icons.psychology,
      ));
    }

    // CONSISTENCY ANALYSIS
    final overallScores = history.map((h) => h.overallScore).toList();
    final consistency = _calculateConsistency(overallScores);

    if (consistency < 0.3) {
      // High variability
      insights.add(const Insight(
        type: InsightType.suggestion,
        title: 'Wellbeing Fluctuating',
        description: 'Your health scores vary significantly day-to-day',
        suggestion: 'Try building consistent daily routines',
        severity: Severity.medium,
        icon: Icons.show_chart,
      ));
    }

    // POSITIVE MOMENTUM
    if (history.length >= 7) {
      final recentWeek = history.sublist(history.length - 7);
      final recentAvg = recentWeek
              .map((h) => h.overallScore)
              .reduce((a, b) => a + b) /
          recentWeek.length;

      if (recentAvg > 75) {
        insights.add(const Insight(
          type: InsightType.positive,
          title: 'Excellent Week!',
          description: 'Your wellbeing is in the top 20%',
          suggestion: 'Share your success with family',
          severity: Severity.info,
          icon: Icons.emoji_events,
        ));
      }
    }

    // Sort by severity (high → medium → info)
    insights.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return insights;
  }

  /// Calculate trend direction and magnitude
  static double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;

    // Compare first half to second half
    final midpoint = values.length ~/ 2;
    final firstHalf = values.sublist(0, midpoint);
    final secondHalf = values.sublist(midpoint);

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    if (firstAvg == 0) return 0.0;

    return (secondAvg - firstAvg) / firstAvg;
  }

  /// Calculate Pearson correlation coefficient
  static double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    double numerator = 0;
    double denomX = 0;
    double denomY = 0;

    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      numerator += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    if (denomX == 0 || denomY == 0) return 0.0;

    return numerator / (math.sqrt(denomX) * math.sqrt(denomY));
  }

  /// Calculate consistency (inverse of coefficient of variation)
  static double _calculateConsistency(List<double> values) {
    if (values.length < 2) return 1.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0.0;

    final variance = values
            .map((v) => math.pow(v - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;

    final stdDev = math.sqrt(variance);
    final coefficientOfVariation = stdDev / mean;

    // Invert so higher = more consistent
    return 1.0 / (1.0 + coefficientOfVariation);
  }

  /// Get trend summary for a specific metric
  static TrendSummary getTrendSummary(List<double> values) {
    if (values.isEmpty) {
      return const TrendSummary(
        direction: TrendDirection.stable,
        magnitude: 0.0,
        description: 'No data',
      );
    }

    final trend = _calculateTrend(values);

    if (trend > 0.15) {
      return TrendSummary(
        direction: TrendDirection.up,
        magnitude: trend,
        description: 'Improving',
      );
    } else if (trend < -0.15) {
      return TrendSummary(
        direction: TrendDirection.down,
        magnitude: trend.abs(),
        description: 'Declining',
      );
    } else {
      return TrendSummary(
        direction: TrendDirection.stable,
        magnitude: trend.abs(),
        description: 'Stable',
      );
    }
  }
}

/// Insight types
enum InsightType {
  warning,
  positive,
  discovery,
  suggestion,
}

/// Severity levels
enum Severity {
  info,
  medium,
  high,
}

/// Insight model
class Insight {
  final InsightType type;
  final String title;
  final String description;
  final String suggestion;
  final Severity severity;
  final IconData icon;

  const Insight({
    required this.type,
    required this.title,
    required this.description,
    required this.suggestion,
    required this.severity,
    required this.icon,
  });

  Color get color {
    switch (type) {
      case InsightType.warning:
        return Colors.orange;
      case InsightType.positive:
        return Colors.green;
      case InsightType.discovery:
        return Colors.blue;
      case InsightType.suggestion:
        return Colors.purple;
    }
  }
}

/// Trend direction
enum TrendDirection {
  up,
  down,
  stable,
}

/// Trend summary
class TrendSummary {
  final TrendDirection direction;
  final double magnitude;
  final String description;

  const TrendSummary({
    required this.direction,
    required this.magnitude,
    required this.description,
  });

  IconData get icon {
    switch (direction) {
      case TrendDirection.up:
        return Icons.trending_up;
      case TrendDirection.down:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
    }
  }

  Color get color {
    switch (direction) {
      case TrendDirection.up:
        return Colors.green;
      case TrendDirection.down:
        return Colors.red;
      case TrendDirection.stable:
        return Colors.grey;
    }
  }
}
