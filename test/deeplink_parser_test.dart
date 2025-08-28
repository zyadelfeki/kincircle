import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/utils/deeplink_parser.dart';

void main() {
  test('extractInviteId parses valid invite URIs', () {
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/invite/abc123')), 'abc123');
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/invite/xyz')), 'xyz');
  });

  test('extractInviteId returns null for invalid URIs', () {
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/')), isNull);
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/invite/')), isNull);
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/invite')), isNull);
    expect(extractInviteId(Uri.parse('https://links.kincircle.app/something/else')), isNull);
  });
}
