import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/telemetry_service.dart';

void main() {
  test('TelemetryService respects sample rate', () async {
    final events = <Map<String, dynamic>>[];

    // Force sample rate to 0.0 to drop events
    final svcDrop = TelemetryService(
      sampleRateProvider: () => 0.0,
      rng: Random(1),
      eventWriter: (e) async => events.add(e),
    );
    await svcDrop.logInviteEvent(inviteId: 'A', event: 'accepted', uid: 'u1');
    expect(events, isEmpty);

    // Force sample rate to 1.0 to always log
    final svcAll = TelemetryService(
      sampleRateProvider: () => 1.0,
      rng: Random(1),
      eventWriter: (e) async => events.add(e),
    );
    await svcAll.logInviteEvent(inviteId: 'B', event: 'declined');
    expect(events.length, 1);
    expect(events.first['inviteId'], 'B');
    expect(events.first['event'], 'declined');
  });
}
