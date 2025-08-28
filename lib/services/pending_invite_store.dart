import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingInviteStore extends ChangeNotifier {
  static const _key = 'pending_invite_id';

  String? _inviteId;
  String? get inviteId => _inviteId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _inviteId = prefs.getString(_key);
    notifyListeners();
  }

  Future<void> set(String? id) async {
    _inviteId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
    notifyListeners();
  }

  /// Returns and clears the pending invite id atomically.
  Future<String?> consume() async {
    final id = _inviteId;
    if (id != null) {
      await set(null);
    }
    return id;
  }
}
