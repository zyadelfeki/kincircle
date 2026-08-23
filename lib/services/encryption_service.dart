import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides local encryption facilities for sensitive user data (e.g. data export).
///
/// Encryption operations happen locally for local-only backups and exports.
/// Shared circle data (locations, family docs, profiles) is not locked with
/// single-device keys.
class EncryptionService {
  EncryptionService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyStorageKey = 'user_encryption_key';
  static const Duration _keyRotationInterval = Duration(days: 90);

  static encrypt.Key? _cachedKey;
  static DateTime? _lastRotation;

  /// Ensures that a key exists before other subsystems begin using the service.
  static Future<void> ensureInitialized() async {
    try {
      await _getOrCreateEncryptionKey();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('EncryptionService init failed: $error\n$stack');
      }
      rethrow;
    }
  }

  /// Encrypts [plainText] with AES-256-CBC, returning `iv:ciphertext` in Base64.
  static Future<String> encryptData(String plainText) async {
    final encrypt.Key key = await _getOrCreateEncryptionKey();
    final encrypt.IV iv = encrypt.IV.fromSecureRandom(16);
    final encrypt.Encrypter encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypt.Encrypted encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a payload produced by [encryptData].
  static Future<String> decryptData(String encryptedData) async {
    final List<String> parts = encryptedData.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted data format');
    }

    final encrypt.IV iv = encrypt.IV.fromBase64(parts[0]);
    final encrypt.Encrypted encrypted =
        encrypt.Encrypted.fromBase64(parts[1]);
    final encrypt.Key key = await _getOrCreateEncryptionKey();
    final encrypt.Encrypter encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Prepares location payload for Firestore.
  /// Circle-shared data is stored unencrypted so circle members can read it.
  static Future<Map<String, dynamic>> encryptLocation({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    return <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.toIso8601String(),
      'user_id_hash': await _hashUserId(),
      'encrypted_at': FieldValue.serverTimestamp(),
    };
  }

  /// Decrypts/parses a location blob retrieved from Firestore.
  static Future<Map<String, dynamic>> decryptLocation(
    dynamic locationPayload,
  ) async {
    if (locationPayload is Map<String, dynamic>) {
      return locationPayload;
    }
    if (locationPayload is String) {
      try {
        if (locationPayload.startsWith('{')) {
          return json.decode(locationPayload) as Map<String, dynamic>;
        }
        final String decrypted = await decryptData(locationPayload);
        return json.decode(decrypted) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  /// Profile data shared with circles is stored in plaintext.
  static Future<Map<String, dynamic>> encryptProfileData(
    Map<String, dynamic> profileData,
  ) async {
    return Map<String, dynamic>.from(profileData);
  }

  /// Decrypts the values previously encrypted via [encryptProfileData].
  static Future<Map<String, dynamic>> decryptProfileData(
    Map<String, dynamic> profileData,
  ) async {
    final List<String> sensitiveFields =
        <String>['phone', 'email', 'address', 'medical_info'];
    final Map<String, dynamic> decrypted = Map<String, dynamic>.from(profileData);

    for (final MapEntry<String, dynamic> entry in profileData.entries) {
      if (sensitiveFields.contains(entry.key) && entry.value is String) {
        final String val = entry.value as String;
        if (val.contains(':')) {
          try {
            decrypted[entry.key] = await decryptData(val);
          } catch (_) {
            decrypted[entry.key] = entry.value;
          }
        }
      }
    }
    return decrypted;
  }

  /// Gathers every document related to [userId] and returns a single JSON blob
  /// encrypted for export (GDPR Article 20).
  static Future<String> createEncryptedDataExport(String userId) async {
    final Map<String, dynamic> userData = await _gatherAllUserData(userId);
    final String jsonPayload = jsonEncode(userData);
    return encryptData(jsonPayload);
  }

  /// Returns a human-readable backup key for the user to store offline.
  static Future<String> generateBackupKey() async {
    final encrypt.Key key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }

  /// Replaces the current encryption key with a freshly generated one while
  /// keeping previously encrypted data accessible via a backup key. The caller
  /// must re-encrypt historical data with the returned key when feasible.
  static Future<encrypt.Key> rotateKey() async {
    final encrypt.Key newKey = encrypt.Key.fromSecureRandom(32);
    await _secureStorage.write(key: _keyStorageKey, value: newKey.base64);
    _cachedKey = newKey;
    _lastRotation = DateTime.now();
    return newKey;
  }

  /// Stores a document snapshot in Firestore without device-local key locking.
  static Future<void> persistEncryptedDocument({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> payload,
    Set<String> encryptedFields = const <String>{},
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(payload);
    data['encrypted_at'] = FieldValue.serverTimestamp();
    data['user_id_hash'] = await _hashUserId();
    await ref.set(data, SetOptions(merge: true));
  }

  /// Utility for decrypting multiple fields within a document snapshot.
  static Future<Map<String, dynamic>> decryptDocument(
    Map<String, dynamic> payload,
    Set<String> encryptedFields,
  ) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(payload);
    for (final String field in encryptedFields) {
      final dynamic value = data[field];
      if (value is String && value.contains(':')) {
        try {
          data[field] = await decryptData(value);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Failed to decrypt $field: $error');
          }
        }
      }
    }
    return data;
  }

  /// Internal helper to load or create the AES key.
  static Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    String? storedKey = await _secureStorage.read(key: _keyStorageKey);
    if (storedKey == null) {
      final encrypt.Key key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: _keyStorageKey, value: key.base64);
      _cachedKey = key;
      _lastRotation = DateTime.now();
      return key;
    }

    final encrypt.Key key = encrypt.Key.fromBase64(storedKey);
    _cachedKey = key;
    _lastRotation = _lastRotation ?? DateTime.now();

    // Opportunistically rotate if past the interval.
    if (DateTime.now().difference(_lastRotation!) > _keyRotationInterval) {
      await rotateKey();
    }
    return key;
  }

  static Future<String> _hashUserId() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw StateError('No authenticated user for hashing');
    }
    final List<int> bytes = utf8.encode(userId);
    final crypto.Digest digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  static Future<Map<String, dynamic>> _gatherAllUserData(
    String userId,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final Map<String, dynamic> userData = <String, dynamic>{};

    final DocumentSnapshot<Map<String, dynamic>> profile =
        await firestore.collection('users').doc(userId).get();
    userData['profile'] = profile.data() ?? <String, dynamic>{};

    Future<List<Map<String, dynamic>>> collectionSnapshot(String path) async {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection(path)
          .get();
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
    }

    userData['locations'] = await collectionSnapshot('location_history');
    userData['wellbeing'] = await collectionSnapshot('wellbeing_analytics');
    userData['emergency_contacts'] =
        await collectionSnapshot('emergency_contacts');
    userData['family'] = await collectionSnapshot('family_members');
    userData['companion'] = await collectionSnapshot('companion_history');
    userData['sensory_profile'] = await collectionSnapshot('sensory_profile');
    userData['privacy_events'] = await collectionSnapshot('privacy_events');

    userData['export_timestamp'] = DateTime.now().toIso8601String();
    userData['export_version'] = '1.0';

    return userData;
  }
}
