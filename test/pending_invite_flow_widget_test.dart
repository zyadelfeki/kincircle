import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kincircle/services/pending_invite_store.dart';
import 'package:kincircle/screens/family/accept_invite_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('stored invite id + successful login -> AcceptInviteScreen is pushed', (tester) async {
    final pendingStore = PendingInviteStore();
    await pendingStore.load();
    await pendingStore.set('TEST_INVITE_999');
    expect(pendingStore.inviteId, 'TEST_INVITE_999');

    await tester.pumpWidget(
      ChangeNotifierProvider<PendingInviteStore>.value(
        value: pendingStore,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final store = Provider.of<PendingInviteStore>(context, listen: false);
                    final inviteId = await store.consume();
                    if (inviteId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AcceptInviteScreen(inviteId: inviteId),
                        ),
                      );
                    }
                  },
                  child: const Text('Simulate Post-Login'),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Simulate Post-Login'), findsOneWidget);
    await tester.tap(find.text('Simulate Post-Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AcceptInviteScreen), findsOneWidget);
    expect(pendingStore.inviteId, isNull);
  });
}
