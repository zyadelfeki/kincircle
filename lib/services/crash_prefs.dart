import 'package:shared_preferences/shared_preferences.dart';

class CrashPrefs {
  static const _kLastCrashKey = 'last_crash_message';
  static const _kLastCrashTimeKey = 'last_crash_time_epoch_ms';

  Future<void> setLastCrash({required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastCrashKey, message);
    await prefs.setInt(_kLastCrashTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<String?> getLastCrashMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastCrashKey);
  }

  Future<DateTime?> getLastCrashTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastCrashTimeKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastCrashKey);
    await prefs.remove(_kLastCrashTimeKey);
  }
}
