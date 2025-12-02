import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'encryption_service.dart';

/// Handles GDPR Article 20 compliant data exports for the authenticated user.
class DataExportService {
  DataExportService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Supported export formats.
  static const List<String> supportedFormats = <String>['json', 'csv'];

  /// Exports the current user's data and returns the generated file reference.
  static Future<File> exportUserData({
    required String format,
    bool includeEncrypted = false,
  }) async {
    if (!supportedFormats.contains(format)) {
      throw ArgumentError('Unsupported format: $format');
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user for export');
    }

    if (kDebugMode) {
      debugPrint('📦 Gathering user data for ${user.uid}...');
    }

    final Map<String, dynamic> data =
        await _gatherCompleteUserData(user.uid, includeEncrypted);

    File file;
    if (format == 'json') {
      file = await _createJsonExport(data);
    } else {
      file = await _createCsvExport(data);
    }

    if (includeEncrypted) {
      final String encrypted = await EncryptionService.encryptData(
        await file.readAsString(),
      );
      await file.writeAsString(encrypted);
    }

    if (kDebugMode) {
      debugPrint('✅ Export complete: ${file.path}');
    }

    return file;
  }

  /// Shares the exported file using the system share sheet.
  static Future<void> shareExport(File exportFile) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Your personal data export from KinCircle (GDPR compliant, machine-readable).',
        subject: 'KinCircle Data Export',
        files: <XFile>[XFile(exportFile.path)],
      ),
    );
  }

  /// Creates recurring exports via WorkManager-style background jobs (placeholder).
  static Future<void> scheduleAutoExport({
    required Duration interval,
    required String format,
  }) async {
    if (!supportedFormats.contains(format)) {
      throw ArgumentError('Unsupported format: $format');
    }
    if (kDebugMode) {
      debugPrint('📅 Auto-export scheduled every ${interval.inDays} days');
    }
  }

  static Future<Map<String, dynamic>> _gatherCompleteUserData(
    String userId,
    bool includeEncrypted,
  ) async {
    final Map<String, dynamic> data = <String, dynamic>{};

    Future<List<Map<String, dynamic>>> collection(String name,
        {Query<Map<String, dynamic>>? query}) async {
      Query<Map<String, dynamic>> ref = _firestore
          .collection('users')
          .doc(userId)
          .collection(name);
      if (query != null) {
        ref = query;
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await ref.get();
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
          .toList();
    }

    final DocumentSnapshot<Map<String, dynamic>> profileDoc =
        await _firestore.collection('users').doc(userId).get();
    Map<String, dynamic> profile = profileDoc.data() ?? <String, dynamic>{};
    if (!includeEncrypted) {
      profile = await EncryptionService.decryptProfileData(profile);
    }
    data['profile'] = profile;

    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 90));
    data['family'] = await collection('family_members');
    data['locations'] = await _firestore
        .collection('users')
        .doc(userId)
        .collection('location_history')
        .where('timestamp', isGreaterThan: cutoff)
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
            .toList());
    data['wellbeing'] = await collection('wellbeing_analytics');
    data['emergency_contacts'] = await collection('emergency_contacts');
    data['companion'] = await collection('companion_history');
    data['sensory_profile'] = await collection('sensory_profile');
    data['consents'] = await collection('consents');

    data['export_metadata'] = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'data_version': '1.0',
      'gdpr_compliant': true,
      'encrypted_payload': includeEncrypted,
    };

    return data;
  }

  static Future<File> _createJsonExport(Map<String, dynamic> data) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final File file = File('${dir.path}/kincircle_export_$timestamp.json');
    final String pretty = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(pretty);
    return file;
  }

  static Future<File> _createCsvExport(Map<String, dynamic> data) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final File file = File('${dir.path}/kincircle_export_$timestamp.csv');
    final List<String> lines = <String>['Category,Field,Value,Timestamp'];

    void addRow(String category, String field, Object? value) {
      final String safeValue = value == null
          ? 'null'
          : value is Map || value is List
              ? jsonEncode(value)
              : value.toString();
      lines.add('$category,"$field","$safeValue",${DateTime.now()}');
    }

    data.forEach((String category, dynamic value) {
      if (value is Map<String, dynamic>) {
        value.forEach((String field, dynamic nested) {
          addRow(category, field, nested);
        });
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          final dynamic item = value[i];
          if (item is Map<String, dynamic>) {
            item.forEach((String field, dynamic nested) {
              addRow('$category[$i]', field, nested);
            });
          } else {
            addRow(category, '$i', item);
          }
        }
      } else {
        addRow(category, 'value', value);
      }
    });

    await file.writeAsString(lines.join('\n'));
    return file;
  }
}
