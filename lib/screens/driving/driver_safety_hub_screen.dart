import 'package:flutter/material.dart';
import '../../services/trip_service.dart';
import '../../services/trip_service_manager.dart';
import '../../models/trip.dart';
import 'driving_mode_screen.dart';
import 'safety_report_screen.dart';
import 'trip_detail_screen.dart';

class DriverSafetyHubScreen extends StatefulWidget {
  const DriverSafetyHubScreen({super.key});

  @override
  State<DriverSafetyHubScreen> createState() => _DriverSafetyHubScreenState();
}

class _DriverSafetyHubScreenState extends State<DriverSafetyHubScreen> {
  final TripService _tripService = TripService();
  final TripServiceManager _tripServiceManager = TripServiceManager();
  
  @override
  void initState() {
    super.initState();
    // TripServiceManager is now initialized globally in main.dart
    // No need to initialize here
  }

  Future<void> _startTestTrip() async {
    try {
      // Create a test trip for development/testing
      await _tripService.createTestTrip();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test trip created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Safety'),
        actions: [
          StreamBuilder<bool>(
            stream: Stream.periodic(const Duration(seconds: 1))
                .map((_) => _tripServiceManager.tripDetectionService?.isRecording ?? false),
            builder: (context, snapshot) {
              final isRecording = snapshot.data ?? false;
              if (isRecording) {
                return Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Recording',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_car_filled_rounded),
                        label: const Text('Start a Drive'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DrivingModeScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.summarize_rounded),
                        label: const Text('Test Trip'),
                        onPressed: () => _startTestTrip(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assessment_rounded),
                        label: const Text('Safety Report'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SafetyReportScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Trip statistics
          StreamBuilder<List<Trip>>(
            stream: _tripService.getUserTrips(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              final trips = snapshot.data ?? [];
              final stats = _calculateTripStats(trips);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Statistics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Trips',
                            '${stats['totalTrips']}',
                            Icons.route_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Distance',
                            '${stats['totalDistance']?.toStringAsFixed(1)} km',
                            Icons.straighten_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Avg Duration',
                            '${stats['avgDuration']?.toStringAsFixed(0)} min',
                            Icons.timer_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'This Week',
                            '${stats['thisWeek']}',
                            Icons.calendar_today_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Trip history
          Expanded(
            child: StreamBuilder<List<Trip>>(
              stream: _tripService.getUserTrips(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading trips: ${snapshot.error}'),
                  );
                }

                final trips = snapshot.data ?? [];

                if (trips.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No trips recorded yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start driving to automatically record your trips',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Recent Trips',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return _buildTripListItem(trip);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripListItem(Trip trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.route_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          title: Text(
            '${trip.startAddress} → ${trip.endAddress}',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(trip.formattedDate),
              Text(
                '${trip.distanceKm.toStringAsFixed(1)} km • ${trip.formattedDuration}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: trip),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateTripStats(List<Trip> trips) {
    if (trips.isEmpty) {
      return {
        'totalTrips': 0,
        'totalDistance': 0.0,
        'avgDuration': 0.0,
        'thisWeek': 0,
      };
    }

    final totalDistance = trips.fold<double>(0.0, (sum, trip) => sum + trip.distanceKm);
    final totalDuration = trips.fold<double>(0.0, (sum, trip) => sum + trip.durationMinutes);
    final avgDuration = totalDuration / trips.length;

    // Count trips from this week
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekTrips = trips.where((trip) {
      return trip.startTime.isAfter(weekStart);
    }).length;

    return {
      'totalTrips': trips.length,
      'totalDistance': totalDistance,
      'avgDuration': avgDuration,
      'thisWeek': thisWeekTrips,
    };
  }
}
