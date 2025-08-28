import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/crash_prefs.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String? _lastCrash;
  DateTime? _lastCrashTime;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = CrashPrefs();
    final msg = await prefs.getLastCrashMessage();
    final time = await prefs.getLastCrashTime();
    if (!mounted) return;
    setState(() {
      _lastCrash = msg;
      _lastCrashTime = time;
    });
  }

  Future<void> _sendReport() async {
    if (_lastCrash == null) return;
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('app_crash_reports').add({
        'userId': uid,
        'message': _lastCrash,
        'time': _lastCrashTime?.toIso8601String(),
        'reportedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crash report sent. Thank you!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crash status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_lastCrash == null)
              const Text('No crash detected in last session.')
            else ...[
              Text('Last crash: ${_lastCrashTime ?? 'unknown time'}'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_lastCrash!),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendReport,
                  icon: const Icon(Icons.send),
                  label: Text(_sending ? 'Sending…' : 'Send Report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
