import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'remote_config_service.dart';

class TelemetryService {
  final FirebaseFirestore? _firestoreOpt;
  final double Function() _sampleRateProvider;
  final Random _rng;
  final Future<void> Function(Map<String, dynamic>)? _eventWriter;

  TelemetryService({
    FirebaseFirestore? firestore,
    double Function()? sampleRateProvider,
    Random? rng,
    Future<void> Function(Map<String, dynamic>)? eventWriter,
  })  : _firestoreOpt = firestore,
        _sampleRateProvider = sampleRateProvider ?? (() => RemoteConfigService().inviteTelemetrySampleRate),
        _rng = rng ?? Random(),
        _eventWriter = eventWriter;

  bool _shouldLog() {
    final rate = _sampleRateProvider().clamp(0.0, 1.0);
    return _rng.nextDouble() < rate;
  }

  Future<void> logInviteEvent({required String inviteId, required String event, String? uid}) async {
    if (!_shouldLog()) return;
    final data = <String, dynamic>{
      'inviteId': inviteId,
      'event': event,
      if (uid != null) 'uid': uid,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (_eventWriter != null) {
      await _eventWriter!(data);
    } else {
  final store = _firestoreOpt ?? FirebaseFirestore.instance;
  await store.collection('invite_events').add(data);
    }
  }
}
