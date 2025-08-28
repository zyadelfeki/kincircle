import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/dynamic_link_service.dart';

void main() {
  group('NoopDynamicLinkService', () {
    test('getInitialInviteId returns null', () async {
      final svc = NoopDynamicLinkService();
      final id = await svc.getInitialInviteId();
      expect(id, isNull);
    });

    test('listenForInvites does not invoke callback', () async {
      final svc = NoopDynamicLinkService();
      var called = false;
      svc.listenForInvites((_) {
        called = true;
      });
      // Nothing to trigger; ensure remains false
      expect(called, isFalse);
    });
  });
}
