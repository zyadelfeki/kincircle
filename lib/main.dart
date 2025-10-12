import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
// Dynamic links are accessed via a small abstraction to ease testing.
import 'services/dynamic_link_service.dart';
import 'services/app_links_dynamic_link_service.dart';

// Import the new screens and theme
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_signup_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/permission_screen.dart';
import 'screens/support/help_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/family/invite_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/family/accept_invite_screen.dart';
import 'screens/family/manage_invites_screen.dart';
import 'screens/geofencing/add_geofence_screen.dart';
import 'screens/driving/driver_safety_hub_screen.dart';
import 'screens/emergency/emergency_contacts_screen.dart';
import 'services/driver_safety/driver_safety_service.dart';
import 'services/auth_service.dart';
import 'services/remote_config_service.dart';
import 'services/pending_invite_store.dart';
import 'utils/theme.dart';
import 'widgets/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/onboarding_prefs.dart';
import 'screens/alerts/alerts_screen.dart';
import 'services/crash_prefs.dart';
import 'screens/support/diagnostics_screen.dart';

Future<void> main() async {
  if (kDebugMode) debugPrint("--- App starting ---");
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) debugPrint("--- WidgetsBinding initialized ---");
  // Opt-in toggle for using the Firebase Auth Emulator in dev builds.
  // Enable with: --dart-define=USE_AUTH_EMULATOR=true
  const String useAuthEmulator = String.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: 'false');
  
  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // You can add error reporting service here
  };

  // Handle errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    // You can add error reporting service here
    return true;
  };

  try {
  await Firebase.initializeApp().timeout(const Duration(seconds: 10));
  if (kDebugMode) debugPrint("--- Firebase initialized ---");
  } catch (e, st) {
  if (kDebugMode) debugPrint("!!! Firebase initialize failed or timed out: $e\n$st");
  }
  // If requested, point Firebase Auth to the local emulator (does nothing if emulator isn't running).
  try {
    if (useAuthEmulator.toLowerCase() == 'true') {
      // Android emulator host mapping for localhost.
      FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
      if (kDebugMode) debugPrint('--- Firebase Auth Emulator enabled at 10.0.2.2:9099 ---');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('!!! Failed to enable Auth Emulator: $e');
  }
  try {
    await RemoteConfigService().init().timeout(const Duration(seconds: 5));
    if (kDebugMode) debugPrint("--- RemoteConfig initialized ---");
  } catch (e, st) {
    if (kDebugMode) debugPrint("!!! RemoteConfig init failed or timed out: $e\n$st");
  }
  // Pass uncaught errors to Crashlytics if Firebase is initialized.
  FlutterError.onError = (errorDetails) {
    try {
      // This will throw if Firebase isn't initialized; guard it.
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  // Save a compact message for Diagnostics
  CrashPrefs().setLastCrash(message: errorDetails.exceptionAsString());
    } catch (_) {}
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  CrashPrefs().setLastCrash(message: '$error');
    } catch (_) {}
    return true;
  };

  // Handle cold start dynamic link via service (allows swapping a Noop in tests)
  // Default to App/Universal Links implementation.
  final DynamicLinkService linkService = AppLinksDynamicLinkService();
  String? initialInviteId;
  try {
    initialInviteId = await linkService
        .getInitialInviteId()
        .timeout(const Duration(seconds: 2));
  } catch (e) {
    if (kDebugMode) debugPrint("!!! getInitialInviteId timed out or failed: $e");
  }
  if (kDebugMode) debugPrint("--- Preparing to call runApp() ---");
  runApp(KinCircleApp(
    initialInviteId: initialInviteId,
    dynamicLinkService: linkService,
  ));
  if (kDebugMode) debugPrint("--- runApp() called ---");
}

class KinCircleApp extends StatefulWidget {
  final String? initialInviteId;
  final DynamicLinkService? dynamicLinkService;
  const KinCircleApp({super.key, this.initialInviteId, this.dynamicLinkService});

  @override
  State<KinCircleApp> createState() => _KinCircleAppState();
}

class _KinCircleAppState extends State<KinCircleApp> {
  String? _pendingInviteId;
  DynamicLinkService? _linkService;
  final PendingInviteStore _pending = PendingInviteStore();

  @override
  void initState() {
    super.initState();
  _pendingInviteId = widget.initialInviteId;
  // Persist any initial invite to survive auth flow.
  _pending.set(_pendingInviteId);
    _linkService = widget.dynamicLinkService;

    // Listen for foreground links (if service provided)
    _linkService?.listenForInvites((inviteId) {
      _pending.set(inviteId);
      // Only navigate immediately if already authenticated; otherwise AuthWrapper will handle after login.
      final ctx = globalNavigatorKey.currentContext;
  final user = ctx != null ? Provider.of<AuthService>(ctx, listen: false).user : null;
      if (user != null) {
        _navigateToInvite(inviteId);
      }
    });

    // Handle cold start invite if provided
    if (_pendingInviteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = globalNavigatorKey.currentContext;
  final user = ctx != null ? Provider.of<AuthService>(ctx, listen: false).user : null;
        if (user != null) {
          _navigateToInvite(_pendingInviteId!);
        }
      });
    }
  }

  void _navigateToInvite(String inviteId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(globalNavigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (_) => AcceptInviteScreen(inviteId: inviteId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<PendingInviteStore>.value(value: _pending),
      ],
      child: MaterialApp(
        title: 'KinCircle',
        theme: kinCircleTheme,
        home: const AuthWrapper(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/auth': (context) => const LoginSignupScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/permissions': (context) => const PermissionScreen(),
          '/help': (context) => const HelpScreen(),
          '/onboarding': (context) {
            final uid = Provider.of<AuthService>(context, listen: false).user?.uid;
            return uid == null ? const WelcomeScreen() : OnboardingScreen(userId: uid);
          },
          '/invite': (context) => const InviteScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/alerts': (context) => const AlertsScreen(),
          '/add-geofence': (context) => const AddGeofenceScreen(),
          '/driver-safety': (context) => const DriverSafetyHubScreen(),
          '/emergency-contacts': (context) => const EmergencyContactsScreen(),
          '/accept-invite': (context) => const Scaffold(),
          '/manage-invites': (context) => const ManageInvitesScreen(),
          '/diagnostics': (context) => const DiagnosticsScreen(),
        },
        builder: (context, widget) {
          Widget error = const ErrorHandler();
          if (widget is Scaffold || widget is Navigator) {
            error = Scaffold(body: Center(child: error));
          }
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) => error;
          return widget ?? error;
        },
        navigatorKey: globalNavigatorKey,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
  if (kDebugMode) debugPrint("--- AuthWrapper building ---");
  final firebaseUser = context.watch<AuthService>().user;
  if (kDebugMode) debugPrint("--- Current user state: ${firebaseUser?.uid ?? 'Logged Out'} ---");
    if (firebaseUser != null) {
  if (kDebugMode) debugPrint("--- User is logged in, showing DashboardScreen ---");
      // Check if onboarding/welcome tour is needed
  return FutureBuilder<Map<String, dynamic>?>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get().then((d) => d.data()),
          OnboardingPrefs().hasSeenWelcomeTour(),
        ]).then((values) => {
              'doc': values[0],
              'seen': values[1],
            }),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }
          final data = snapshot.data ?? {};
          final doc = data['doc'] as Map<String, dynamic>?;
          final hasSeenLocal = (data['seen'] as bool?) ?? false;
          final needsOnboarding = !(doc?['userSetupComplete'] == true) || !hasSeenLocal;
          if (needsOnboarding) {
            return OnboardingScreen(userId: firebaseUser.uid);
          }
          // Opportunistically trigger weekly driver summary upload
      // (privacy-preserving: counts only; raw data stays local)
      DriverSafetyService(
        // No interpreter needed here; we’re only aggregating incidents
        interpreterFactory: (_) async => throw UnimplementedError(),
      ).uploadWeeklySummaryIfNeeded();
      // If a pending invite exists, route to accept flow, then show dashboard.
      final pending = context.read<PendingInviteStore>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Defer work; avoid using BuildContext across async gaps by re-fetching navigator state.
        pending.consume().then((id) {
          if (id == null) return;
          final nav = globalNavigatorKey.currentState;
          if (nav == null || !nav.mounted) return;
          // Informational banner before navigation
          ScaffoldMessenger.of(nav.context).showSnackBar(
            const SnackBar(
              content: Text('Joining family…'),
              duration: Duration(seconds: 2),
            ),
          );
          final future = nav.push(
            MaterialPageRoute(
              builder: (_) => AcceptInviteScreen(inviteId: id),
            ),
          );
          future.then((_) {
            final nav2 = globalNavigatorKey.currentState;
            if (nav2 == null || !nav2.mounted) return;
            ScaffoldMessenger.of(nav2.context).showSnackBar(
              const SnackBar(content: Text('Invite opened')),
            );
          });
        });
      });
          return const DashboardScreen();
        },
      );
    }
  if (kDebugMode) debugPrint("--- User is logged out, showing WelcomeScreen ---");
    return const WelcomeScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'KinCircle\nSplash Screen',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
} 

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
