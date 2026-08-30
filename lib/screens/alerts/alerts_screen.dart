import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../widgets/nav_shell.dart';
import 'alert_details_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  bool _showUnreadOnly = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  Map<String, String> _memberNamesByUid = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in.';
        });
        return;
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100);
      if (_showUnreadOnly) {
        query = query.where('seen', isEqualTo: false);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      final Map<String, String> memberNames =
          await _loadMemberNamesFromAlerts(snapshot.docs);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _docs = snapshot.docs;
        _memberNamesByUid = memberNames;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String msg = 'Something went wrong. Please try again.';
      if (e.code == 'permission-denied') {
        msg = 'Something went wrong. Please try again.';
      } else if (e.code == 'failed-precondition') {
        msg = 'Index not ready yet. Please wait a minute and try again.';
      }
      debugPrint('AlertsScreen error: ${e.code} — ${e.message}');
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('AlertsScreen unexpected error: $e');
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _markRead(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await doc.reference.set({'seen': true}, SetOptions(merge: true));
    _load();
  }

  Future<void> _markAllRead() async {
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in _docs) {
      final bool seen = doc.data()['seen'] as bool? ?? false;
      if (!seen) {
        batch.set(doc.reference, {'seen': true}, SetOptions(merge: true));
      }
    }
    await batch.commit();
    _load();
  }

  bool _looksLikeUid(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('@')) return false;
    return RegExp(r'^[a-zA-Z0-9_-]{16,}$').hasMatch(trimmed);
  }

  Set<String> _candidateAlertUserIds(Map<String, dynamic> data) {
    final List<dynamic> candidates = <dynamic>[
      data['triggeredByUid'],
      data['triggeredByUserId'],
      data['senderUid'],
      data['memberUid'],
      data['uid'],
      data['triggeredBy'],
      data['userId'],
    ];

    final Set<String> ids = <String>{};
    for (final dynamic candidate in candidates) {
      final String value = (candidate ?? '').toString().trim();
      if (_looksLikeUid(value)) {
        ids.add(value);
      }
    }
    return ids;
  }

  bool _isGenericMemberPlaceholder(String value) {
    final String lowered = value.trim().toLowerCase();
    return lowered == 'family member' ||
        lowered == 'member' ||
        lowered == 'unknown' ||
        lowered == 'unknown member' ||
        lowered == 'a family member' ||
        lowered == 'someone';
  }

  Future<Map<String, String>> _loadMemberNamesFromAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final Set<String> userIds = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      userIds.addAll(_candidateAlertUserIds(doc.data()));
    }

    if (userIds.isEmpty) {
      return <String, String>{};
    }

    final List<String> idList = userIds.toList();
    final Map<String, String> names = <String, String>{};

    for (int i = 0; i < idList.length; i += 10) {
      final int end = math.min(i + 10, idList.length);
      final List<String> chunk = idList.sublist(i, end);
      final QuerySnapshot<Map<String, dynamic>> users = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> userDoc
          in users.docs) {
        final Map<String, dynamic> userData = userDoc.data();
        String displayName = (userData['displayName'] ?? '').toString().trim();
        if (displayName.isEmpty) {
          final String email = (userData['email'] ?? '').toString().trim();
          if (email.contains('@')) {
            displayName = email.split('@').first.trim();
          }
        }
        if (displayName.isNotEmpty) {
          names[userDoc.id] = displayName;
        }
      }
    }

    return names;
  }

  String _resolveName(Map<String, dynamic> data) {
    final List<dynamic> candidates = <dynamic>[
      data['triggeredByDisplayName'],
      data['triggeredByName'],
      data['displayName'],
      data['memberName'],
      data['senderName'],
      data['userName'],
      data['triggeredBy'],
    ];

    for (final dynamic candidate in candidates) {
      final String value = (candidate ?? '').toString().trim();
      if (value.isEmpty) continue;
      if (_isGenericMemberPlaceholder(value)) continue;
      if (_looksLikeUid(value)) {
        final String? resolved = _memberNamesByUid[value];
        if (resolved != null && resolved.trim().isNotEmpty) {
          return resolved.trim();
        }
        continue;
      }
      if (value.contains('@')) {
        return value.split('@').first.trim();
      }
      if (value.isNotEmpty) {
        return value;
      }
    }

    for (final String uid in _candidateAlertUserIds(data)) {
      final String? resolved = _memberNamesByUid[uid];
      if (resolved != null && resolved.trim().isNotEmpty) {
        return resolved.trim();
      }
    }
    return 'Unknown member';
  }

  String _prefixNameIfMissing(String text, String name) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final String lower = trimmed.toLowerCase();
    final String lowerName = name.toLowerCase();
    final bool startsWithVerb = lower.startsWith('triggered ') ||
        lower.startsWith('sent ') ||
        lower.startsWith('started ') ||
        lower.startsWith('raised ');
    if (startsWithVerb && !lower.startsWith(lowerName)) {
      return '$name $trimmed';
    }
    return trimmed;
  }

  String _replaceGenericActor(String text, String name) {
    if (name == 'Unknown member') return text;
    return text.replaceAll(
      RegExp(r'\ba family member\b|\bfamily member\b', caseSensitive: false),
      name,
    );
  }

  String _resolveTitle(Map<String, dynamic> data, String name) {
    final String rawTitle = (data['title'] ?? '').toString().trim();
    final String rawMessage = (data['message'] ?? '').toString().trim();
    if (rawTitle.isNotEmpty) {
      final String normalized = _replaceGenericActor(rawTitle, name);
      return _prefixNameIfMissing(normalized, name);
    }
    if (rawMessage.isNotEmpty) {
      final String normalized = _replaceGenericActor(rawMessage, name);
      return _prefixNameIfMissing(normalized, name);
    }
    if (name == 'Unknown member') {
      return 'Emergency alert';
    }
    return '$name triggered an emergency alert!';
  }

  String _resolveMessage(Map<String, dynamic> data, String name) {
    final String rawMessage = (data['message'] ?? '').toString().trim();
    if (rawMessage.isEmpty) {
      return 'Tap to view alert details.';
    }
    return _prefixNameIfMissing(rawMessage, name);
  }

  bool _isUrgentAlert({
    required Map<String, dynamic> data,
    required String title,
    required String message,
  }) {
    final String type = (data['type'] ?? '').toString().toLowerCase();
    final String haystack = '$type ${title.toLowerCase()} ${message.toLowerCase()}';
    return haystack.contains('sos') ||
        haystack.contains('emergency') ||
        haystack.contains('help') ||
        haystack.contains('crash');
  }

  String _relativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final DateTime value = timestamp.toDate();
    final Duration diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Widget _loadingView() {
    final palette = KinCirclePalette.of(context);
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, int index) {
        return Shimmer.fromColors(
          baseColor: palette.surfaceAlt,
          highlightColor: palette.border,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 72,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: KinCircleRadii.card,
            ),
          ),
        );
      },
    );
  }

  Widget _errorView() {
    return _ErrorState(
      title: 'Something went wrong',
      message: _error ?? 'Something went wrong. Please try again.',
      onRetry: _load,
    );
  }

  Widget _emptyView() {
    final palette = KinCirclePalette.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, color: palette.textMuted, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    _showUnreadOnly ? 'No unread alerts' : 'No alerts yet',
                    style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showUnreadOnly
                        ? 'All alerts are already marked as read.'
                        : 'No alerts yet. New family safety alerts will appear here.',
                    style: KinCircleTypography.body14(color: palette.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    final palette = KinCirclePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Text(
        label,
        style: KinCircleTypography.caption12(
          color: palette.textMuted,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAlertTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final palette = KinCirclePalette.of(context);
    final Map<String, dynamic> data = doc.data();
    final String name = _resolveName(data);
    final String title = _resolveTitle(data, name);
    final String message = _resolveMessage(data, name);
    final bool seen = data['seen'] as bool? ?? false;
    final String timeLabel = _relativeTime(data['timestamp'] as Timestamp?);
    final String type = (data['type'] ?? '').toString().toLowerCase();
    final bool isPattern = type == 'pattern' || type == 'rhythm';
    final bool urgent =
        _isUrgentAlert(data: data, title: title, message: message);
    final IconData leadingIcon = urgent
        ? Icons.sos_rounded
        : (isPattern
            ? Icons.schedule_rounded
            : Icons.notifications_none_rounded);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: seen
            ? palette.surface
            : palette.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: seen
                ? palette.border
                : palette.accent,
            width: 3,
          ),
          top: BorderSide(color: palette.border, width: 1),
          right: BorderSide(color: palette.border, width: 1),
          bottom: BorderSide(color: palette.border, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AlertDetailsScreen(alertId: doc.id, alertData: data),
            ),
          );
        },
        leading: Icon(
          leadingIcon,
          color: urgent
              ? palette.error
              : (seen
                  ? palette.textMuted
                  : palette.accent),
        ),
        title: Row(
          children: [
            if (!seen)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: KinCircleTypography.body14(
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KinCircleTypography.caption12(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: KinCircleTypography.caption12(
                  color: seen
                      ? palette.textMuted
                      : palette.accent,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: seen
            ? Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
              )
            : TextButton(
                onPressed: () => _markRead(doc),
                child: const Text('Read'),
              ),
      ),
    );
  }

  Widget _listView() {
    if (_docs.isEmpty) return _emptyView();
    final DateTime now = DateTime.now();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> recentDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> archivedDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in _docs) {
      final Timestamp? ts = doc.data()['timestamp'] as Timestamp?;
      if (ts != null && now.difference(ts.toDate()).inDays > 7) {
        archivedDocs.add(doc);
      } else {
        recentDocs.add(doc);
      }
    }

    final bool hasUnread = _docs.any(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
          !(doc.data()['seen'] as bool? ?? false),
    );

    final palette = KinCirclePalette.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                selected: _showUnreadOnly,
                backgroundColor: palette.surfaceAlt,
                selectedColor: palette.accent,
                side: BorderSide(color: palette.border),
                showCheckmark: true,
                checkmarkColor: Colors.black,
                label: Text(
                  'Unread only',
                  style: KinCircleTypography.caption12(
                    color: _showUnreadOnly
                        ? Colors.black
                        : palette.textMuted,
                    weight: FontWeight.w600,
                  ),
                ),
                onSelected: (bool value) {
                  setState(() => _showUnreadOnly = value);
                  _load();
                },
              ),
              TextButton(
                onPressed: hasUnread ? _markAllRead : null,
                style: KinCircleButtons.ghost(),
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              if (recentDocs.isNotEmpty) _buildSectionHeader('Recent'),
              ...recentDocs.map(_buildAlertTile),
              if (archivedDocs.isNotEmpty)
                _buildSectionHeader('Archive (older than 7 days)'),
              ...archivedDocs.map(_buildAlertTile),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = _loadingView();
    } else if (_error != null) {
      body = _errorView();
    } else {
      body = _listView();
    }

    return NavShell(
      currentIndex: 3,
      title: 'Alerts',
      body: body,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: palette.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}