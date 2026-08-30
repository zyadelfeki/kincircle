import 'package:shared_preferences/shared_preferences.dart';

class ConsentService {
  ConsentService._internal();
  factory ConsentService() => _instance;
  static final ConsentService _instance = ConsentService._internal();
  static const _key = 'ml_consent_given';

  Future<bool> isConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setConsentGiven() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> setConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
