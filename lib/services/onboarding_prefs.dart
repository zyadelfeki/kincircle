import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static const _kHasSeenWelcomeTour = 'hasSeenWelcomeTour';

  Future<bool> hasSeenWelcomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHasSeenWelcomeTour) ?? false;
  }

  Future<void> setSeenWelcomeTour([bool value = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenWelcomeTour, value);
  }
}
