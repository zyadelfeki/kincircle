import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:kincircle/services/theme_controller.dart';
import 'package:kincircle/services/pro_gating_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Soft paywall appears on gated action', (tester) async {
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
                    await ProGatingService().ensureProFeature(context, 'Driver Safety Reports');
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unlock'), findsOneWidget);
  });
}
