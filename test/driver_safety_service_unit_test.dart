import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/driver_safety/driver_safety_service.dart';
import 'package:kincircle/services/driver_safety/interpreter.dart';

class _FakeInterpreter implements DriverInterpreter {
  final List<double> scores;
  _FakeInterpreter(this.scores);
  @override
  List<double> run(List<double> features) => scores;
}

class _MemRepo {
  final List<DriverIncident> saved = [];
  Future<void> save(DriverIncident i) async => saved.add(i);
  Future<List<DriverIncident>> getRecent({int limit = 50}) async => saved.reversed.take(limit).toList();
}

void main() {
  test('processFeatures saves incident when score exceeds threshold', () async {
    final repo = _MemRepo();
    final service = DriverSafetyService(
      interpreterFactory: (asset) async => _FakeInterpreter([0.2, 0.8, 0.1]),
      repoFactory: () async => repo,
    );

    await service.processFeatures(List.filled(12, 0.0), threshold: 0.7);

    final recent = await repo.getRecent(limit: 10);
    expect(recent.length, 1);
    expect(recent.first.type, 'sharp_turn');
    expect(recent.first.score, closeTo(0.8, 1e-9));
  });

  test('processFeatures does not save when below threshold', () async {
    final repo = _MemRepo();
    final service = DriverSafetyService(
      interpreterFactory: (asset) async => _FakeInterpreter([0.3, 0.4, 0.2]),
      repoFactory: () async => repo,
    );

    await service.processFeatures(List.filled(12, 0.0), threshold: 0.7);
    final recent = await repo.getRecent(limit: 10);
    expect(recent, isEmpty);
  });
}
