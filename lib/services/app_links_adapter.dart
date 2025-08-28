import 'dart:async';

import 'package:app_links/app_links.dart';

/// Lightweight adapter to decouple from the app_links plugin for testability.
abstract class AppLinksAdapter {
  Future<Uri?> getInitialLink();
  Stream<Uri> get uriLinkStream;
}

class RealAppLinksAdapter implements AppLinksAdapter {
  final AppLinks _inner = AppLinks();

  @override
  Future<Uri?> getInitialLink() => _inner.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _inner.uriLinkStream;
}
