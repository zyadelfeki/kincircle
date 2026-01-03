import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_safety/driver_safety_service.dart';

/// Driver Safety Summary Screen showing weekly safety reports and statistics
class DriverSafetySummaryScreen extends StatefulWidget {
  const DriverSafetySummaryScreen({super.key});

  @override
  State<DriverSafetySummaryScreen> createState() => _DriverSafetySummaryScreenState();
}

class _DriverSafetySummaryScreenState extends State<DriverSafetySummaryScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driverService = Provider.of<DriverSafetyService>(context, listen: false);
      driverService.fetchWeeklySummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Safety Report'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Consumer<DriverSafetyService>(
        builder: (context, driverService, child) {
          if (driverService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => driverService.fetchWeeklySummary(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Weekly Summary Card
                _buildWeeklySummaryCard(driverService),
                
                const SizedBox(height: 16),
                
                // Safety Score Card
                _buildSafetyScoreCard(driverService),
                
                const SizedBox(height: 16),
                
                // Recent Incidents Card
                _buildRecentIncidentsCard(driverService),
                
                const SizedBox(height: 16),
                
                // Coaching Tips Card
                _buildCoachingTipsCard(driverService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklySummaryCard(DriverSafetyService driverService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.amber),
              title: const Text('Harsh Brakes'),
              trailing: Text(
                '${driverService.weeklyHarshBrakes}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.red),
              title: const Text('Harsh Acceleration'),
              trailing: Text(
                '${driverService.weeklyRapidAccel}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.turn_right, color: Colors.orange),
              title: const Text('Sharp Turns'),
              trailing: Text(
                '${driverService.weeklySharpTurns}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.green),
              title: const Text('Total Trips'),
              trailing: Text(
                '${driverService.weeklyTotalTrips}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyScoreCard(DriverSafetyService driverService) {
    final score = driverService.safetyScore;
    final scoreColor = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;
    final scoreLabel = score >= 80 ? 'Excellent Driver' : score >= 60 ? 'Good Driver' : 'Needs Improvement';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Score',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withValues(alpha: 0.1),
                      border: Border.all(color: scoreColor, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(scoreLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentIncidentsCard(DriverSafetyService driverService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Incidents',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<DriverIncident>>(
              stream: driverService.incidentStream,
              initialData: driverService.recentIncidents,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && 
                    snapshot.data?.isEmpty == true) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final incidents = snapshot.data ?? [];
                
                if (incidents.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('No recent incidents'),
                    subtitle: Text('Keep up the great driving!'),
                    contentPadding: EdgeInsets.zero,
                  );
                }

                return Column(
                  children: incidents.map((incident) => 
                    _buildIncidentListTile(incident)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentListTile(DriverIncident incident) {
    IconData icon;
    Color color;
    String title;

    switch (incident.type) {
      case 'harsh_brake':
        icon = Icons.warning;
        color = Colors.amber;
        title = 'Harsh Brake';
        break;
      case 'rapid_accel':
        icon = Icons.speed;
        color = Colors.red;
        title = 'Harsh Acceleration';
        break;
      case 'sharp_turn':
        icon = Icons.turn_right;
        color = Colors.orange;
        title = 'Sharp Turn';
        break;
      default:
        icon = Icons.error;
        color = Colors.grey;
        title = 'Unknown Incident';
    }

    // Format the timestamp
    final now = DateTime.now();
    final difference = now.difference(incident.timestamp);
    String timeAgo;
    
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      timeAgo = 'Just now';
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text('Severity: ${(incident.score * 100).toInt()}% • $timeAgo'),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCoachingTipsCard(DriverSafetyService driverService) {
    // Generate contextual tips based on the most common incident type
    String tip = 'Keep maintaining safe driving habits!';
    
    if (driverService.weeklyHarshBrakes > driverService.weeklyRapidAccel && 
        driverService.weeklyHarshBrakes > driverService.weeklySharpTurns) {
      tip = 'Try to maintain a 3-second following distance to reduce harsh braking.';
    } else if (driverService.weeklyRapidAccel > driverService.weeklySharpTurns) {
      tip = 'Gradual acceleration saves fuel and reduces wear on your vehicle.';
    } else if (driverService.weeklySharpTurns > 0) {
      tip = 'Take turns slowly and smoothly for better control and passenger comfort.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Tips',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
