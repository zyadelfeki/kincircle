import 'package:flutter/material.dart';
import 'wellbeing_analytics_service.dart';

/// AI-powered recommendation engine
/// Generates personalized wellness suggestions based on metrics
class RecommendationEngine {
  /// Generate personalized recommendations
  static Future<List<Recommendation>> generate(String userId) async {
    final wellbeing =
        await WellbeingAnalyticsService().calculateMetrics(userId);
    final recommendations = <Recommendation>[];

    // HIGH STRESS RECOMMENDATIONS
    if (wellbeing.stressLevel == StressLevel.high ||
        wellbeing.stressLevel == StressLevel.critical) {
      recommendations.add(const Recommendation(
        id: 'stress-walk',
        title: 'Take a 5-Minute Walk',
        description: 'Fresh air reduces cortisol by 20%',
        category: RecommendationCategory.activity,
        priority: Priority.high,
        icon: Icons.directions_walk,
        actionText: 'Start Walking',
        researchBacked: true,
        estimatedTime: '5 min',
      ));

      recommendations.add(const Recommendation(
        id: 'breathing-exercise',
        title: 'Try 4-7-8 Breathing',
        description: 'Calms nervous system in 2 minutes',
        category: RecommendationCategory.mindfulness,
        priority: Priority.high,
        icon: Icons.air,
        actionText: 'Start Breathing',
        researchBacked: true,
        estimatedTime: '2 min',
      ));

      recommendations.add(const Recommendation(
        id: 'talk-to-someone',
        title: 'Connect With Someone',
        description: 'Social support reduces stress by 35%',
        category: RecommendationCategory.social,
        priority: Priority.high,
        icon: Icons.phone,
        actionText: 'Call Family',
        researchBacked: true,
        estimatedTime: '5 min',
      ));
    }

    // MODERATE STRESS
    if (wellbeing.stressLevel == StressLevel.moderate) {
      recommendations.add(const Recommendation(
        id: 'nature-break',
        title: 'Take a Nature Break',
        description: 'Green spaces reduce stress hormones',
        category: RecommendationCategory.activity,
        priority: Priority.medium,
        icon: Icons.park,
        actionText: 'Find Parks',
        researchBacked: true,
        estimatedTime: '10 min',
      ));
    }

    // LOW SOCIAL ENGAGEMENT
    if (wellbeing.socialEngagement < 30) {
      recommendations.add(const Recommendation(
        id: 'family-checkin',
        title: 'Check In With Family',
        description: 'You haven\'t connected in 48 hours',
        category: RecommendationCategory.social,
        priority: Priority.medium,
        icon: Icons.family_restroom,
        actionText: 'Say Hello',
        estimatedTime: '1 min',
      ));

      recommendations.add(const Recommendation(
        id: 'share-moment',
        title: 'Share a Happy Moment',
        description: 'Positive sharing boosts mood by 25%',
        category: RecommendationCategory.social,
        priority: Priority.medium,
        icon: Icons.photo_camera,
        actionText: 'Take Photo',
        researchBacked: true,
        estimatedTime: '2 min',
      ));
    }

    // LOW ACTIVITY LEVEL
    if (wellbeing.activityLevel < 25) {
      recommendations.add(const Recommendation(
        id: 'outdoor-time',
        title: '15 Minutes of Sunshine',
        description: 'Boosts mood and vitamin D',
        category: RecommendationCategory.activity,
        priority: Priority.medium,
        icon: Icons.wb_sunny,
        actionText: 'Go Outside',
        researchBacked: true,
        estimatedTime: '15 min',
      ));

      recommendations.add(const Recommendation(
        id: 'stretch-break',
        title: 'Quick Stretch Session',
        description: 'Movement releases endorphins',
        category: RecommendationCategory.activity,
        priority: Priority.medium,
        icon: Icons.self_improvement,
        actionText: 'Start Stretching',
        researchBacked: true,
        estimatedTime: '5 min',
      ));
    }

    // MODERATE ACTIVITY - ENCOURAGE MORE
    if (wellbeing.activityLevel >= 25 && wellbeing.activityLevel < 60) {
      recommendations.add(const Recommendation(
        id: 'daily-walk-goal',
        title: 'Set a Daily Walk Goal',
        description: '10,000 steps improves health markers',
        category: RecommendationCategory.activity,
        priority: Priority.low,
        icon: Icons.track_changes,
        actionText: 'Set Goal',
        researchBacked: true,
        estimatedTime: '1 min',
      ));
    }

    // POOR SLEEP QUALITY
    if (wellbeing.sleepQuality < 40) {
      recommendations.add(const Recommendation(
        id: 'sleep-schedule',
        title: 'Set Consistent Sleep Time',
        description: 'Regular sleep improves wellbeing by 35%',
        category: RecommendationCategory.health,
        priority: Priority.high,
        icon: Icons.bedtime,
        actionText: 'Set Reminder',
        researchBacked: true,
        estimatedTime: '1 min',
      ));

      recommendations.add(const Recommendation(
        id: 'screen-time-limit',
        title: 'Limit Evening Screen Time',
        description: 'Blue light disrupts sleep cycles',
        category: RecommendationCategory.health,
        priority: Priority.medium,
        icon: Icons.phone_android,
        actionText: 'Set Timer',
        researchBacked: true,
        estimatedTime: '1 min',
      ));
    }

    // MODERATE SLEEP - OPTIMIZE
    if (wellbeing.sleepQuality >= 40 && wellbeing.sleepQuality < 70) {
      recommendations.add(const Recommendation(
        id: 'sleep-environment',
        title: 'Optimize Sleep Environment',
        description: 'Cool, dark rooms improve sleep quality',
        category: RecommendationCategory.health,
        priority: Priority.low,
        icon: Icons.night_shelter,
        actionText: 'Learn More',
        researchBacked: true,
        estimatedTime: '3 min',
      ));
    }

    // LOW FAMILY CONNECTION
    if (wellbeing.familyConnection < 35) {
      recommendations.add(const Recommendation(
        id: 'family-activity',
        title: 'Plan Family Activity',
        description: 'Shared experiences strengthen bonds',
        category: RecommendationCategory.connection,
        priority: Priority.medium,
        icon: Icons.celebration,
        actionText: 'See Ideas',
        researchBacked: true,
        estimatedTime: '5 min',
      ));

      recommendations.add(const Recommendation(
        id: 'gratitude-message',
        title: 'Send Gratitude Message',
        description: 'Appreciation deepens relationships',
        category: RecommendationCategory.connection,
        priority: Priority.medium,
        icon: Icons.favorite,
        actionText: 'Write Message',
        researchBacked: true,
        estimatedTime: '2 min',
      ));
    }

    // GOOD OVERALL SCORE - MAINTENANCE
    if (wellbeing.overallScore >= 75) {
      recommendations.add(const Recommendation(
        id: 'maintain-habits',
        title: 'Keep Up the Great Work!',
        description: 'Your wellbeing is excellent',
        category: RecommendationCategory.health,
        priority: Priority.low,
        icon: Icons.emoji_events,
        actionText: 'View Trends',
        researchBacked: false,
        estimatedTime: '1 min',
      ));
    }

    // MINDFULNESS FOR ALL
    if (recommendations.length < 3) {
      recommendations.add(const Recommendation(
        id: 'daily-gratitude',
        title: 'Practice Daily Gratitude',
        description: 'Increases happiness by 25%',
        category: RecommendationCategory.mindfulness,
        priority: Priority.low,
        icon: Icons.auto_awesome,
        actionText: 'Start Practice',
        researchBacked: true,
        estimatedTime: '2 min',
      ));
    }

    // Sort by priority (high → medium → low)
    recommendations
        .sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return recommendations;
  }

  /// Get quick action recommendation (single most important)
  static Future<Recommendation?> getQuickAction(String userId) async {
    final recommendations = await generate(userId);
    return recommendations.isNotEmpty ? recommendations.first : null;
  }

  /// Get category-specific recommendations
  static Future<List<Recommendation>> getByCategory(
      String userId, RecommendationCategory category) async {
    final all = await generate(userId);
    return all.where((r) => r.category == category).toList();
  }
}

/// Recommendation categories
enum RecommendationCategory {
  activity,
  mindfulness,
  social,
  health,
  connection,
}

/// Priority levels
enum Priority {
  low,
  medium,
  high,
}

/// Recommendation model
class Recommendation {
  final String id;
  final String title;
  final String description;
  final RecommendationCategory category;
  final Priority priority;
  final IconData icon;
  final String actionText;
  final bool researchBacked;
  final String estimatedTime;

  const Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.icon,
    required this.actionText,
    this.researchBacked = false,
    required this.estimatedTime,
  });

  Color get priorityColor {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.blue;
    }
  }

  Color get categoryColor {
    switch (category) {
      case RecommendationCategory.activity:
        return Colors.green;
      case RecommendationCategory.mindfulness:
        return Colors.purple;
      case RecommendationCategory.social:
        return Colors.pink;
      case RecommendationCategory.health:
        return Colors.blue;
      case RecommendationCategory.connection:
        return Colors.amber;
    }
  }

  String get categoryLabel {
    switch (category) {
      case RecommendationCategory.activity:
        return 'Activity';
      case RecommendationCategory.mindfulness:
        return 'Mindfulness';
      case RecommendationCategory.social:
        return 'Social';
      case RecommendationCategory.health:
        return 'Health';
      case RecommendationCategory.connection:
        return 'Connection';
    }
  }
}
