import 'package:flutter/material.dart';

/// Driver Safety Summary Screen showing weekly safety reports and statistics
class DriverSafetySummaryScreen extends StatelessWidget {
  const DriverSafetySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Safety Report'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Weekly Summary Card
          Card(
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
                  const ListTile(
                    leading: Icon(Icons.warning, color: Colors.amber),
                    title: Text('Harsh Brakes'),
                    trailing: Text('3', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const ListTile(
                    leading: Icon(Icons.speed, color: Colors.red),
                    title: Text('Harsh Acceleration'),
                    trailing: Text('1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const ListTile(
                    leading: Icon(Icons.turn_right, color: Colors.orange),
                    title: Text('Sharp Turns'),
                    trailing: Text('2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const ListTile(
                    leading: Icon(Icons.route, color: Colors.green),
                    title: Text('Total Trips'),
                    trailing: Text('12', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Safety Score Card
          Card(
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
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.green, width: 3),
                          ),
                          child: const Center(
                            child: Text(
                              '85',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Good Driver'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recent Incidents Card
          Card(
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
                  const ListTile(
                    leading: Icon(Icons.warning, color: Colors.amber),
                    title: Text('Harsh Brake'),
                    subtitle: Text('Main St & 5th Ave • Today 2:45 PM'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const ListTile(
                    leading: Icon(Icons.speed, color: Colors.red),
                    title: Text('Harsh Acceleration'),
                    subtitle: Text('Highway 101 • Yesterday 8:30 AM'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const ListTile(
                    leading: Icon(Icons.turn_right, color: Colors.orange),
                    title: Text('Sharp Turn'),
                    subtitle: Text('Oak Street • Dec 3, 4:15 PM'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Coaching Tips Card
          Card(
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
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Try to maintain a 3-second following distance to reduce harsh braking.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
