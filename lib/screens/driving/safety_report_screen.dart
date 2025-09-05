import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kincircle/services/driver_safety/driver_safety_service.dart';

class SafetyReportScreen extends StatefulWidget {
  const SafetyReportScreen({super.key});

  @override
  State<SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends State<SafetyReportScreen> {
  late final DriverSafetyService _service;
  bool _loading = true;
  List<DriverIncident> _incidents = const [];
  int? _driverSafetyScore;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _service = DriverSafetyService(
      // No interpreter needed to read from local storage
      interpreterFactory: (_) async => throw UnimplementedError(),
    );
    _load();
  }

  Future<void> _load() async {
    if (!Hive.isAdapterRegistered(0)) {
      await Hive.initFlutter();
    }
    final data = await _service.getRecent(limit: 100);
    // Fetch driverSafetyScore from Firestore for the current user (if signed in)
    int? score;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final v = snap.data()?['driverSafetyScore'];
        if (v is int) score = v;
      }
    } catch (_) {
      // ignore fetch errors for offline mode
    }
    if (!mounted) return;
    setState(() {
      _incidents = data;
      _loading = false;
      _driverSafetyScore = score;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
              ? const Center(child: Text('No incidents recorded yet'))
              : ListView.separated(
                  itemCount: _incidents.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final s = _driverSafetyScore;
                      return ListTile(
                        leading: const Icon(Icons.speed_rounded,
                            color: Colors.blueAccent),
                        title: const Text('Weekly Driver Safety Score'),
                        subtitle:
                            const Text('Calculated from anonymized summaries'),
                        trailing: Text(s != null ? '$s / 100' : '—'),
                      );
                    }
                    final i = _incidents[index - 1];
                    return ListTile(
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      title: Text(_formatType(i.type)),
                      subtitle: Text(i.timestamp.toLocal().toString()),
                      trailing: Text(i.score.toStringAsFixed(2)),
                    );
                  },
                ),
      floatingActionButton: kDebugMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'upload_now_btn',
                  onPressed: _uploading ? null : _uploadNow,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload Summary Now'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'refresh_btn',
                  onPressed: _load,
                  child: const Icon(Icons.refresh),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: _load,
              child: const Icon(Icons.refresh),
            ),
    );
  }

  Future<void> _uploadNow() async {
    setState(() => _uploading = true);
    try {
      await _service.uploadWeeklySummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly summary uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _formatType(String t) {
    switch (t) {
      case 'harsh_brake':
        return 'Harsh Braking';
      case 'sharp_turn':
        return 'Sharp Turn';
      case 'rapid_accel':
        return 'Rapid Acceleration';
      default:
        return t;
    }
  }
}
