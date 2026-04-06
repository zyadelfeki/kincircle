import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SendGridService {
  SendGridService(
      {required this.apiKey,
      required this.fromEmail,
      this.fromName = 'KinCircle'});
  final String apiKey;
  final String fromEmail;
  final String fromName;

  bool get isConfigured => apiKey.isNotEmpty && fromEmail.isNotEmpty;

  Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String html,
    String? plain,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint(
          'WARNING: SendGrid API key not configured. Email features disabled.');
      return;
    }
    if (fromEmail.isEmpty) {
      debugPrint(
          'WARNING: SendGrid sender email not configured. Email features disabled.');
      return;
    }

    final uri = Uri.parse('https://api.sendgrid.com/v3/mail/send');
    final body = {
      'personalizations': [
        {
          'to': [
            {'email': toEmail}
          ]
        }
      ],
      'from': {'email': fromEmail, 'name': fromName},
      'subject': subject,
      'content': [
        if (plain != null) {'type': 'text/plain', 'value': plain},
        {'type': 'text/html', 'value': html},
      ],
    };
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode >= 300) {
      throw Exception('SendGrid error: ${res.statusCode} ${res.body}');
    }
  }
}
