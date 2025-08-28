import 'package:shared_preferences/shared_preferences.dart';

class UiPrefs {
  static const _kLastSheetSize = 'lastSheetSize';

  Future<double> getLastSheetSize({double fallback = 0.11}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kLastSheetSize) ?? fallback;
  }

  Future<void> setLastSheetSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastSheetSize, size);
  }
}
