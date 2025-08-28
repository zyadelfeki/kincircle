import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/app_links_adapter.dart';
import 'package:kincircle/services/app_links_dynamic_link_service.dart';

class _FakeAdapter implements AppLinksAdapter {
  Uri? initial;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initial;

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void add(Uri uri) => _controller.add(uri);
  void dispose() => _controller.close();
}

void main() {
  group('AppLinksDynamicLinkService', () {
    test('getInitialInviteId parses valid invite path', () async {
      final fake = _FakeAdapter()..initial = Uri.parse('https://links.kincircle.app/invite/ABC123');
      final svc = AppLinksDynamicLinkService(adapter: fake);
      expect(await svc.getInitialInviteId(), 'ABC123');
      fake.dispose();
    });

    test('getInitialInviteId returns null for non-invite path', () async {
      final fake = _FakeAdapter()..initial = Uri.parse('https://links.kincircle.app/other');
      final svc = AppLinksDynamicLinkService(adapter: fake);
      expect(await svc.getInitialInviteId(), isNull);
      fake.dispose();
    });

    test('listenForInvites emits only invite IDs', () async {
      final fake = _FakeAdapter();
      final svc = AppLinksDynamicLinkService(adapter: fake);
      final ids = <String>[];
      svc.listenForInvites(ids.add);
      fake.add(Uri.parse('https://links.kincircle.app/invite/ZZZ999'));
      fake.add(Uri.parse('https://links.kincircle.app/ignored'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ids, ['ZZZ999']);
      fake.dispose();
    });
  });
}
