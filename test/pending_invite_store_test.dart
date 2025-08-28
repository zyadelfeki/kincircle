import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/services/pending_invite_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  test('PendingInviteStore set/get/consume cycle', () async {
    final store = PendingInviteStore();
    await store.load();
    await store.set('ABC');
    expect(store.inviteId, 'ABC');
    final consumed = await store.consume();
    expect(consumed, 'ABC');
    expect(store.inviteId, isNull);
  });
}
