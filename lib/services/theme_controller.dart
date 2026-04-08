import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Controls app ThemeMode (system/light/dark) and a reactive "Pro" accent flag.
/// Values are persisted to SharedPreferences.
class ThemeController extends ChangeNotifier {
  static const _kThemeModeKey = 'appearance.themeMode';
  static const _kProKey = 'subscription.isPro';

  ThemeMode _mode = ThemeMode.light;
  bool _isPro = false;
  bool _loaded = false;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  StreamSubscription? _userSub;

  ThemeMode get mode => _mode;
  bool get isPro => _isPro;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final modeStr = p.getString(_kThemeModeKey);
      switch (modeStr) {
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _mode = ThemeMode.light;
      }
      _isPro = p.getBool(_kProKey) ?? false;
    } catch (_) {
      // Defaults already set
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    try {
      final p = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        _ => 'system'
      };
      await p.setString(_kThemeModeKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setPro(bool isPro) async {
    _isPro = isPro;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kProKey, isPro);
    } catch (_) {}
    notifyListeners();
  }

  // Start listening to the current user's profile for subscription changes.
  // Expects a boolean field `isPro` in users/{uid}.
  void startUserProSync() {
    _userSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    _userSub = _userStream!.listen((doc) async {
      final val = doc.data()?['isPro'];
      if (val is bool && val != _isPro) {
        await setPro(val);
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
