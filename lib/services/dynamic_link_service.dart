// A small abstraction around Firebase Dynamic Links so we can swap it out in tests
// and contain deprecations in one place.
// ignore_for_file: deprecated_member_use

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import '../utils/deeplink_parser.dart';

abstract class DynamicLinkService {
  Future<String?> getInitialInviteId();
  void listenForInvites(void Function(String inviteId) onInvite);
}

class FirebaseDynamicLinkService implements DynamicLinkService {
  @override
  Future<String?> getInitialInviteId() async {
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
  if (initialLink == null) return null;
  return extractInviteId(initialLink.link);
  }

  @override
  void listenForInvites(void Function(String inviteId) onInvite) {
    FirebaseDynamicLinks.instance.onLink.listen((event) {
      final id = extractInviteId(event.link);
      if (id != null) onInvite(id);
    });
  }
}

class NoopDynamicLinkService implements DynamicLinkService {
  @override
  Future<String?> getInitialInviteId() async => null;

  @override
  void listenForInvites(void Function(String inviteId) onInvite) {
    // no-op
  }
}
