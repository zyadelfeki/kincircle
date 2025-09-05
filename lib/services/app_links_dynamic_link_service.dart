// Dynamic links via platform-native App/Universal Links using app_links
// Keeps the same interface as DynamicLinkService for easy swap.

import 'dynamic_link_service.dart';
import '../utils/deeplink_parser.dart';
import 'app_links_adapter.dart';

class AppLinksDynamicLinkService implements DynamicLinkService {
  AppLinksDynamicLinkService({AppLinksAdapter? adapter})
      : _appLinks = adapter ?? RealAppLinksAdapter();
  final AppLinksAdapter _appLinks;
  @override
  Future<String?> getInitialInviteId() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return null;
      return extractInviteId(uri);
    } catch (_) {
      // Some platforms may throw if not configured yet; treat as no initial link.
      return null;
    }
  }

  @override
  void listenForInvites(void Function(String inviteId) onInvite) {
    _appLinks.uriLinkStream.listen((uri) {
      final id = extractInviteId(uri);
      if (id != null) onInvite(id);
    });
  }
}
