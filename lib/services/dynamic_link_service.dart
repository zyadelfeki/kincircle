// Dynamic Link abstraction; default implementation uses native App/Universal Links (see AppLinksDynamicLinkService).
// Firebase Dynamic Links has been removed due to deprecation. A legacy implementation can be reintroduced in a
// separate file if ever needed, without adding a hard dependency here.

// Removed unused import of deeplink_parser.dart

abstract class DynamicLinkService {
  Future<String?> getInitialInviteId();
  void listenForInvites(void Function(String inviteId) onInvite);
}

class NoopDynamicLinkService implements DynamicLinkService {
  @override
  Future<String?> getInitialInviteId() async => null;

  @override
  void listenForInvites(void Function(String inviteId) onInvite) {
    // no-op
  }
}
