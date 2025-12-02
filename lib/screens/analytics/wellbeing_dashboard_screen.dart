import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/wellbeing_analytics_service.dart';
import '../../services/recommendation_engine.dart';
import '../../services/trend_analysis_service.dart';

/// Comprehensive family wellbeing dashboard
class WellbeingDashboardScreen extends StatefulWidget {
  const WellbeingDashboardScreen({super.key});

  @override
  State<WellbeingDashboardScreen> createState() =>
      _WellbeingDashboardScreenState();
}

class _WellbeingDashboardScreenState extends State<WellbeingDashboardScreen> {
  WellbeingMetrics? _currentMetrics;
  List<Recommendation> _recommendations = [];
  List<WellbeingMetrics> _trendHistory = [];
  List<Insight> _insights = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWellbeingData();
  }

  Future<void> _loadWellbeingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please sign in to view wellbeing data';
          _isLoading = false;
        });
        return;
      }

      final analytics = WellbeingAnalyticsService();

      // Load current metrics
      final metrics = await analytics.calculateMetrics(user.uid);

      // Generate recommendations
      final recommendations = await RecommendationEngine.generate(user.uid);

      // Load 7-day trend history
      final history = await analytics.getHistory(user.uid, days: 7);

      // Generate insights
      final insights = await TrendAnalysisService.analyze(user.uid);

      setState(() {
        _currentMetrics = metrics;
        _recommendations = recommendations;
        _trendHistory = history;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading wellbeing data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Wellbeing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showWellbeingInfo,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWellbeingData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentMetrics == null) {
      return const Center(child: Text('No wellbeing data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadWellbeingData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallScoreCard(),
            const SizedBox(height: 24),
            Text(
              'Your Wellbeing',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            if (_insights.isNotEmpty) ...[
              Text(
                'AI Insights',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildInsightsList(),
              const SizedBox(height: 24),
            ],
            if (_recommendations.isNotEmpty) ...[
              Text(
                'Recommendations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildRecommendationsList(),
              const SizedBox(height: 24),
            ],
            if (_trendHistory.length >= 3) ...[
              Text(
                '7-Day Trends',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildTrendsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScoreCard() {
    final score = _currentMetrics!.overallScore;
    final color = _getScoreColor(score);
    final status = _getScoreStatus(score);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Overall Family Health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${score.toInt()}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      status,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getScoreDescription(score),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Stress',
          _getStressLevelText(_currentMetrics!.stressLevel),
          _getStressLevelIcon(_currentMetrics!.stressLevel),
          _getStressLevelColor(_currentMetrics!.stressLevel),
        ),
        _buildMetricCard(
          'Activity',
          '${_currentMetrics!.activityLevel.toInt()}%',
          Icons.directions_run,
          _getScoreColor(_currentMetrics!.activityLevel),
        ),
        _buildMetricCard(
          'Sleep',
          '${_currentMetrics!.sleepQuality.toInt()}%',
          Icons.bedtime,
          _getScoreColor(_currentMetrics!.sleepQuality),
        ),
        _buildMetricCard(
          'Social',
          '${_currentMetrics!.socialEngagement.toInt()}%',
          Icons.people,
          _getScoreColor(_currentMetrics!.socialEngagement),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsList() {
    return Column(
      children: _insights.take(3).map((insight) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: insight.color.withValues(alpha: 0.2),
              child: Icon(insight.icon, color: insight.color),
            ),
            title: Text(
              insight.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(insight.description),
                const SizedBox(height: 4),
                Text(
                  insight.suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendationsList() {
    return Column(
      children: _recommendations.take(4).map((rec) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: rec.categoryColor.withValues(alpha: 0.2),
              child: Icon(rec.icon, color: rec.categoryColor),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    rec.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (rec.researchBacked)
                  const Icon(
                    Icons.verified,
                    size: 16,
                    color: Colors.blue,
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(rec.description),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        rec.categoryLabel,
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: rec.categoryColor.withValues(alpha: 0.2),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rec.estimatedTime,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rec.priorityColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.priority.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: rec.priorityColor,
                ),
              ),
            ),
            isThreeLine: true,
            onTap: () => _handleRecommendationAction(rec),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrendsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTrendRow(
              'Overall Score',
              _trendHistory.map((h) => h.overallScore).toList(),
            ),
            const Divider(),
            _buildTrendRow(
              'Activity',
              _trendHistory.map((h) => h.activityLevel).toList(),
            ),
            const Divider(),
            _buildTrendRow(
              'Sleep',
              _trendHistory.map((h) => h.sleepQuality).toList(),
            ),
            const Divider(),
            _buildTrendRow(
              'Social',
              _trendHistory.map((h) => h.socialEngagement).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendRow(String label, List<double> values) {
    final summary = TrendAnalysisService.getTrendSummary(values);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 30,
              child: _buildSparkline(values),
            ),
          ),
          const SizedBox(width: 12),
          Icon(summary.icon, size: 20, color: summary.color),
          const SizedBox(width: 4),
          Text(
            summary.description,
            style: TextStyle(fontSize: 12, color: summary.color),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline(List<double> values) {
    if (values.isEmpty) return const SizedBox();

    return CustomPaint(
      painter: SparklinePainter(values),
    );
  }

  // HELPER METHODS

  Color _getScoreColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getScoreStatus(double score) {
    if (score >= 75) return 'Excellent';
    if (score >= 50) return 'Good';
    if (score >= 25) return 'Fair';
    return 'Needs Attention';
  }

  String _getScoreDescription(double score) {
    if (score >= 75) {
      return 'Your family wellbeing is excellent! Keep up the healthy habits.';
    } else if (score >= 50) {
      return 'Your wellbeing is good, with room for improvement.';
    } else if (score >= 25) {
      return 'Consider focusing on stress reduction and connection.';
    } else {
      return 'Let\'s work together to improve your family health.';
    }
  }

  String _getStressLevelText(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return 'Low';
      case StressLevel.moderate:
        return 'Moderate';
      case StressLevel.high:
        return 'High';
      case StressLevel.critical:
        return 'Critical';
    }
  }

  IconData _getStressLevelIcon(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return Icons.sentiment_satisfied;
      case StressLevel.moderate:
        return Icons.sentiment_neutral;
      case StressLevel.high:
        return Icons.sentiment_dissatisfied;
      case StressLevel.critical:
        return Icons.warning;
    }
  }

  Color _getStressLevelColor(StressLevel level) {
    switch (level) {
      case StressLevel.low:
        return Colors.green;
      case StressLevel.moderate:
        return Colors.orange;
      case StressLevel.high:
        return Colors.red;
      case StressLevel.critical:
        return Colors.red.shade900;
    }
  }

  void _handleRecommendationAction(Recommendation rec) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${rec.actionText} - Feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWellbeingInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('How It Works'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Wellbeing Analytics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'We analyze your behavioral patterns to infer wellbeing:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text('• Movement patterns indicate activity levels'),
              Text('• Location data shows social engagement'),
              Text('• Late-night activity estimates sleep quality'),
              Text('• Check-ins measure family connection'),
              SizedBox(height: 12),
              Text(
                'Research-Backed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Our algorithms are based on published research showing behavioral patterns correlate strongly with mental health.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 12),
              Text(
                'Privacy: All analysis happens privately. Your data never leaves your family circle.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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

/// Custom painter for sparkline charts
class SparklinePainter extends CustomPainter {
  final List<double> values;

  SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    if (range == 0) return;

    final path = Path();
    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalizedValue = (values[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
