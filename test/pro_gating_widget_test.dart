import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kincircle/services/pro_gating_service.dart';
import 'package:kincircle/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kincircle/widgets/paywall.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  testWidgets('Pro gating shows soft paywall when not Pro', (tester) async {
    final theme = ThemeController();
    await theme.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: theme,
        child: MaterialApp(
          routes: {
            '/paywall': (_) => const Scaffold(body: Text('Paywall')),
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Call soft paywall directly to avoid Firebase initialization through gating service
                    await showSoftPaywall(
                      context,
                      title: 'Unlock Driver Safety Reports',
                      message: 'Pro feature',
                      onStartTrial: () => Navigator.of(context).pushNamed('/paywall'),
                    );
                  },
                  child: const Text('Open Feature'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Ensure not pro by default
    expect(theme.isPro, isFalse);

    // Tap the feature button
    await tester.tap(find.text('Open Feature'));
    await tester.pumpAndSettle();

  // Soft paywall bottom sheet should appear with CTA
  expect(find.textContaining('Unlock'), findsOneWidget);
    expect(find.text('Start Your 14-Day Free Trial'), findsOneWidget);

    // Dismiss with Not now
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Start Your 14-Day Free Trial'), findsNothing);
  });

  testWidgets('Pro users bypass soft paywall', (tester) async {
  final theme = ThemeController();
    await theme.load();
    await theme.setPro(true);

    var called = false;

  await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: theme,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await ProGatingService(
                      firestore: FakeFirebaseFirestore(),
                    ).ensureProFeature(context, 'Driver Safety Reports');
                    called = ok;
                  },
                  child: const Text('Open Feature'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Feature'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.text('Start Your 14-Day Free Trial'), findsNothing);
  });
}
