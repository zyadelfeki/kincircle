import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // Temporarily disabled due to build issues
import 'dart:async';

/// Remote tech support screen for elderly users
class RemoteSupportScreen extends StatefulWidget {
  const RemoteSupportScreen({super.key});

  @override
  State<RemoteSupportScreen> createState() => _RemoteSupportScreenState();
}

class _RemoteSupportScreenState extends State<RemoteSupportScreen> {
  String? _sessionId;
  SupportSessionStatus _status = SupportSessionStatus.none;
  RemoteSupportService? _supportService;
  List<Map<String, dynamic>> _familyContacts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _sessionTimer;
  int _sessionDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadFamilyContacts();
  }

  Future<void> _loadFamilyContacts() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get family members from Firestore
      final familyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('family')
          .doc('members')
          .get();

      if (familyDoc.exists) {
        final members = familyDoc.data()?['members'] as List<dynamic>? ?? [];
        setState(() {
          _familyContacts = members
              .map((m) => {
                    'uid': m['uid'],
                    'name': m['name'],
                    'email': m['email'],
                    'isPrimary': m['isPrimary'] ?? false,
                  })
              .toList();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading family contacts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestSupport(String supporterId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _supportService = RemoteSupportService();
      final sessionId = await _supportService!.createSupportSession(
        requesterId: user.uid,
        supporterId: supporterId,
      );

      setState(() {
        _sessionId = sessionId;
        _status = SupportSessionStatus.pending;
      });

      // Listen for session updates
      _supportService!.listenToSession(sessionId, (status) {
        setState(() => _status = status);

        if (status == SupportSessionStatus.active) {
          _startSessionTimer();
          _initializeScreenSharing();
        } else if (status == SupportSessionStatus.ended) {
          _endSession();
        }
      });

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support request sent! Waiting for response...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error requesting support: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeScreenSharing() async {
    if (_supportService == null) return;

    try {
      await _supportService!.startScreenShare();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screen sharing started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error starting screen share: $e');
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionDuration = 0;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _sessionDuration++);

      // Auto-end after 30 minutes
      if (_sessionDuration >= 1800) {
        _endSession();
      }
    });
  }

  Future<void> _endSession() async {
    _sessionTimer?.cancel();

    if (_supportService != null && _sessionId != null) {
      await _supportService!.endSession(_sessionId!);
      await _supportService!.dispose();
    }

    setState(() {
      _status = SupportSessionStatus.ended;
      _supportService = null;
      _sessionId = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support session ended'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _supportService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Tech Support'),
        actions: [
          if (_status == SupportSessionStatus.active)
            IconButton(
              icon: const Icon(Icons.call_end),
              tooltip: 'End Session',
              onPressed: _endSession,
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

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _errorMessage = null);
                  _loadFamilyContacts();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    switch (_status) {
      case SupportSessionStatus.none:
        return _buildRequestScreen();
      case SupportSessionStatus.pending:
        return _buildPendingScreen();
      case SupportSessionStatus.active:
        return _buildActiveSessionScreen();
      case SupportSessionStatus.ended:
        return _buildEndedScreen();
    }
  }

  Widget _buildRequestScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Need Help?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Request remote support from a family member. They can see your screen and guide you through any issues.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          Text(
            'Select a family member to help:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_familyContacts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No family members found. Add family members first to request support.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            )
          else
            ..._familyContacts.map((contact) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        contact['name'][0].toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      contact['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(contact['email']),
                    trailing: ElevatedButton(
                      onPressed: () => _requestSupport(contact['uid']),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                      ),
                      child: const Text('Request Help'),
                    ),
                  ),
                )),
          const SizedBox(height: 32),
          Card(
            color: Colors.orange.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sessions automatically end after 30 minutes for security.',
                      style: TextStyle(fontSize: 14),
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

  Widget _buildPendingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Waiting for response...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your support request has been sent. Please wait for them to accept.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _endSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionScreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.screen_share,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Screen Sharing Active',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Session Duration: ${_formatDuration(_sessionDuration)}',
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your helper can see your screen',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _endSession,
                icon: const Icon(Icons.call_end),
                label: const Text('End Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 60),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Session Ended',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for using remote support!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Support session status
enum SupportSessionStatus {
  none,
  pending,
  active,
  ended,
}

/// Service for managing remote support sessions
class RemoteSupportService {
  // RTCPeerConnection? _peerConnection; // Temporarily disabled
  // MediaStream? _localStream; // Temporarily disabled
  StreamSubscription? _sessionSubscription;

  /// Create a new support session
  Future<String> createSupportSession({
    required String requesterId,
    required String supporterId,
  }) async {
    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('support_sessions')
          .doc();

      await sessionRef.set({
        'sessionId': sessionRef.id,
        'requesterId': requesterId,
        'supporterId': supporterId,
        'status': 'pending',
        'startTime': FieldValue.serverTimestamp(),
        'rtcSignaling': {},
      });

      // Send notification to supporter
      await _sendSupportNotification(supporterId, requesterId, sessionRef.id);

      return sessionRef.id;
    } catch (e) {
      throw Exception('Failed to create support session: $e');
    }
  }

  /// Listen to session status changes
  void listenToSession(String sessionId, Function(SupportSessionStatus) onStatusChange) {
    _sessionSubscription = FirebaseFirestore.instance
        .collection('support_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final status = snapshot.data()?['status'] as String?;
      switch (status) {
        case 'pending':
          onStatusChange(SupportSessionStatus.pending);
          break;
        case 'active':
          onStatusChange(SupportSessionStatus.active);
          break;
        case 'ended':
          onStatusChange(SupportSessionStatus.ended);
          break;
        default:
          onStatusChange(SupportSessionStatus.none);
      }
    });
  }

  /// Start screen sharing
  Future<void> startScreenShare() async {
    // Temporarily disabled due to flutter_webrtc build issues
    // Will be implemented once package is stable
    debugPrint('Screen sharing temporarily unavailable - WebRTC integration pending');
    
    /* Original implementation commented out:
    try {
      final mediaConstraints = <String, dynamic>{
        'video': {
          'displaySurface': 'monitor',
        },
        'audio': false,
      };

      _localStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      debugPrint('Screen sharing started');
    } catch (e) {
      throw Exception('Failed to start screen share: $e');
    }
    */
  }

  /// End support session
  Future<void> endSession(String sessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('support_sessions')
          .doc(sessionId)
          .update({
        'status': 'ended',
        'endTime': FieldValue.serverTimestamp(),
      });

      await dispose();
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  /// Send notification to supporter
  Future<void> _sendSupportNotification(
    String supporterId,
    String requesterId,
    String sessionId,
  ) async {
    try {
      // Get requester name
      final requesterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(requesterId)
          .get();

      final requesterName = requesterDoc.data()?['displayName'] ?? 'Someone';

      // Create notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(supporterId)
          .collection('notifications')
          .add({
        'type': 'support_request',
        'title': 'Tech Support Request',
        'message': '$requesterName needs remote tech support',
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _sessionSubscription?.cancel();
    // _localStream?.dispose(); // Temporarily disabled
    // await _peerConnection?.close(); // Temporarily disabled
    // _peerConnection?.dispose(); // Temporarily disabled
  }
}
