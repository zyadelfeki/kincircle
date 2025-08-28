part of 'driver_safety_service.dart';

class _IncidentRepository {
  static const _boxName = 'driver_incidents';

  final Box _box;

  _IncidentRepository(this._box);

  static Future<_IncidentRepository> create() async {
    if (!Hive.isAdapterRegistered(0)) {
      // Using raw Map storage; no adapter required.
    }
    if (!Hive.isBoxOpen(_boxName)) {
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        Hive.init(dir.path);
      }
    }
    final box = await Hive.openBox(_boxName);
    return _IncidentRepository(box);
  }

  Future<void> save(DriverIncident incident) async {
    await _box.add(incident.toJson());
  }

  Future<List<DriverIncident>> getRecent({int limit = 50}) async {
    final items = _box.values.cast<Map>().toList().reversed.take(limit).toList();
    return items.map(DriverIncident.fromJson).toList();
  }

  Future<List<DriverIncident>> getSince(DateTime sinceUtc) async {
    final all = _box.values.cast<Map>().toList();
    final out = <DriverIncident>[];
    for (final m in all) {
      try {
        final i = DriverIncident.fromJson(m);
        if (i.timestamp.isAfter(sinceUtc)) out.add(i);
      } catch (_) {
        // skip malformed
      }
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }
}
