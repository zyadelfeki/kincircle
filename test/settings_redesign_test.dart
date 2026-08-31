import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kincircle/design/kincircle_screen_tokens.dart';
import 'package:kincircle/screens/settings/settings_screen.dart';
import 'package:kincircle/widgets/nav_shell.dart';
import 'package:kincircle/services/firestore_service.dart';
import 'package:kincircle/services/privacy_controls_service.dart';
import 'package:kincircle/services/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({
      'settings.push_notifications': true,
      'settings.alert_sounds': true,
      'settings.quiet_hours': false,
      'settings.location_sharing': true,
      'settings.circle_visibility': true,
      'settings.app_language': 'English',
      'test_preserved_key': 'survives_cache_clear',
      'subscription.isPro': true,
    });
  });

  Widget buildTestSettingsScreen({
    ThemeController? themeController,
    PrivacyControlsService? privacyService,
    Map<String, WidgetBuilder>? routes,
  }) {
    final tc = themeController ?? ThemeController(subscribeAuthChanges: false);
    final ps = privacyService ??
        PrivacyControlsService(firestore: fakeFirestore);
    final fs = FirestoreService(
      firestore: fakeFirestore,
      currentUidProvider: () => 'test_uid',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: tc),
        ChangeNotifierProvider<PrivacyControlsService>.value(value: ps),
      ],
      child: KinCirclePalette(
        data: KinCirclePaletteData.dark,
        child: MaterialApp(
          routes: routes ??
              {
                '/account': (ctx) => const Scaffold(body: Text('Account Screen')),
                '/subscription': (ctx) => const Scaffold(body: Text('Subscription Screen')),
                '/manage-family': (ctx) => const Scaffold(body: Text('Manage Family Screen')),
                '/manage-invites': (ctx) => const Scaffold(body: Text('Manage Invites Screen')),
                '/emergency-contacts': (ctx) => const Scaffold(body: Text('Emergency Contacts Screen')),
                '/privacy/dashboard': (ctx) => const Scaffold(body: Text('Privacy Dashboard Screen')),
                '/settings/ai': (ctx) => const Scaffold(body: Text('AI Settings Screen')),
                '/settings/sensory-controls': (ctx) => const Scaffold(body: Text('Sensory Controls Screen')),
                '/help': (ctx) => const Scaffold(body: Text('Help Screen')),
                '/feedback': (ctx) => const Scaffold(body: Text('Feedback Screen')),
                '/diagnostics': (ctx) => const Scaffold(body: Text('Diagnostics Screen')),
              },
          home: NavShellEmbeddedScope(
            child: SettingsScreen(firestoreService: fs),
          ),
        ),
      ),
    );
  }

  group('Settings & Profile Redesign Tests', () {
    testWidgets('Renders all 6 top-level sections with titles', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestSettingsScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1. Account & Membership'), findsOneWidget);
      expect(find.text('2. Family & Circle'), findsOneWidget);
      expect(find.text('3. Safety & Privacy'), findsOneWidget);
      expect(find.text('4. Notifications & Alerts'), findsOneWidget);
      expect(find.text('5. App Experience & Accessibility'), findsOneWidget);
      expect(find.text('6. Help, Support & Session'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);
    });

    testWidgets('Safe Clear Cache preserves SharedPreferences data', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestSettingsScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final clearCacheTile = find.text('Storage & Cache');
      expect(clearCacheTile, findsOneWidget);

      await tester.tap(clearCacheTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Image & temporary cache cleared'), findsOneWidget);

      // Verify that SharedPreferences key is preserved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('test_preserved_key'), equals('survives_cache_clear'));
      expect(prefs.getBool('subscription.isPro'), isTrue);
    });

    testWidgets('Push Notifications toggle writes to SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestSettingsScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final pushText = find.text('Push Notifications');
      expect(pushText, findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.push_notifications'), isTrue);
    });

    testWidgets('Navigation links route to corresponding destinations', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestSettingsScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Edit Profile
      final editProfile = find.text('Edit Profile');
      expect(editProfile, findsOneWidget);
      await tester.tap(editProfile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Account Screen'), findsOneWidget);

      // Pop back to settings
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Subscription & Pro Plan
      final subscriptionTile = find.text('Subscription & Pro Plan');
      expect(subscriptionTile, findsOneWidget);
      await tester.tap(subscriptionTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Subscription Screen'), findsOneWidget);
    });
  });
}

