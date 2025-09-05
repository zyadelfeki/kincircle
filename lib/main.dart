import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'screens/family/create_family_screen.dart';
import 'screens/family/manage_family_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/family/accept_invite_screen.dart';
import 'screens/family/manage_invites_screen.dart';
import 'screens/geofencing/add_geofence_screen.dart';
import 'screens/driving/driver_safety_hub_screen.dart';
import 'services/driver_safety/driver_safety_service.dart';
import 'services/trip_service_manager.dart';
import 'services/auth_service.dart';
import 'services/remote_config_service.dart';
import 'services/pending_invite_store.dart';
import 'services/theme_controller.dart';
import 'utils/theme.dart';
import 'widgets/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/onboarding_prefs.dart';
import 'screens/alerts/alerts_screen.dart';
import 'services/crash_prefs.dart';
import 'screens/support/diagnostics_screen.dart';
import 'utils/constants.dart';
import 'screens/account/profile_management_screen.dart';
import 'screens/account/subscription_management_screen.dart';
import 'screens/account/pro_paywall_screen.dart';

Future<void> main() async {
  if (kDebugMode) {
    debugPrint('--- App starting ---');
  }
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint('--- WidgetsBinding initialized ---');
  }
  // Opt-in toggle for using the Firebase Auth Emulator in dev builds.
  // Enable with: --dart-define=USE_AUTH_EMULATOR=true
  const String useAuthEmulator =
      String.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: 'false');

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
    // Initialize with code-based options so we don't depend on google-services.json
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      debugPrint('--- Firebase initialized (code options) ---');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('!!! Firebase initialize failed or timed out: $e\n$st');
    }
  }
  // If requested, point Firebase Auth to the local emulator (does nothing if emulator isn't running).
  try {
    if (useAuthEmulator.toLowerCase() == 'true') {
      // Android emulator host mapping for localhost.
      FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
      if (kDebugMode) {
        debugPrint('--- Firebase Auth Emulator enabled at 10.0.2.2:9099 ---');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('!!! Failed to enable Auth Emulator: $e');
    }
  }
  try {
    await RemoteConfigService().init().timeout(const Duration(seconds: 5));
    if (kDebugMode) {
      debugPrint('--- RemoteConfig initialized ---');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('!!! RemoteConfig init failed or timed out: $e\n$st');
    }
  }

  // Initialize TripServiceManager to handle authentication-aware trip detection
  try {
    await TripServiceManager().initialize();
    if (kDebugMode) {
      debugPrint('--- TripServiceManager initialized ---');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('!!! TripServiceManager init failed: $e\n$st');
    }
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
    if (kDebugMode) {
      debugPrint('!!! getInitialInviteId timed out or failed: $e');
    }
  }
  if (kDebugMode) {
    debugPrint('--- Preparing to call runApp() ---');
  }
  runApp(KinCircleApp(
    initialInviteId: initialInviteId,
    dynamicLinkService: linkService,
  ));
  if (kDebugMode) {
    debugPrint('--- runApp() called ---');
  }
}

class KinCircleApp extends StatefulWidget {
  const KinCircleApp(
      {super.key, this.initialInviteId, this.dynamicLinkService});

  final String? initialInviteId;
  final DynamicLinkService? dynamicLinkService;

  @override
  State<KinCircleApp> createState() => _KinCircleAppState();
}

class _KinCircleAppState extends State<KinCircleApp> {
  String? _pendingInviteId;
  DynamicLinkService? _linkService;
  final PendingInviteStore _pending = PendingInviteStore();
  final ThemeController _themeController = ThemeController();

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
      final user = ctx != null
          ? Provider.of<AuthService>(ctx, listen: false).user
          : null;
      if (user != null) {
        _navigateToInvite(inviteId);
      }
    });

    // Handle cold start invite if provided
    if (_pendingInviteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = globalNavigatorKey.currentContext;
        final user = ctx != null
            ? Provider.of<AuthService>(ctx, listen: false).user
            : null;
        if (user != null) {
          _navigateToInvite(_pendingInviteId!);
        }
      });
    }
    // Load persisted theme preferences
    _themeController.load();
    // Start syncing Pro status from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _themeController.startUserProSync();
    });
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
        ChangeNotifierProvider<ThemeController>.value(value: _themeController),
        ChangeNotifierProvider<DriverSafetyService>(
          create: (_) => DriverSafetyService(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final pro = context.watch<ThemeController>().isPro;
          // Recreate themes to reflect Pro accent dynamically
          final ThemeData light =
              kinTheme(brightness: Brightness.light, pro: pro);
          final ThemeData dark =
              kinTheme(brightness: Brightness.dark, pro: pro);
          return MaterialApp(
            title: 'Kin Arc',
            theme: light,
            darkTheme: dark,
            themeMode: context.watch<ThemeController>().mode,
            home: const AuthWrapper(),
            routes: {
              '/welcome': (context) => const WelcomeScreen(),
              '/auth': (context) => const LoginSignupScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/permissions': (context) => const PermissionScreen(),
              '/help': (context) => const HelpScreen(),
              '/onboarding': (context) {
                final uid =
                    Provider.of<AuthService>(context, listen: false).user?.uid;
                return uid == null
                    ? const WelcomeScreen()
                    : OnboardingScreen(userId: uid);
              },
              '/invite': (context) => const InviteScreen(),
              '/create-family': (context) => const CreateFamilyScreen(),
              '/manage-family': (context) => const ManageFamilyScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/alerts': (context) => const AlertsScreen(),
              '/add-geofence': (context) => const AddGeofenceScreen(),
              '/driver-safety': (context) => const DriverSafetyHubScreen(),
              '/accept-invite': (context) => const Scaffold(),
              '/manage-invites': (context) => const ManageInvitesScreen(),
              '/diagnostics': (context) => const DiagnosticsScreen(),
              '/account': (context) => const ProfileManagementScreen(),
              '/subscription': (context) =>
                  const SubscriptionManagementScreen(),
              '/paywall': (context) => const ProPaywallScreen(),
            },
            builder: (context, widget) {
              // Brand-aligned fatal error UI with retry and support
              ErrorWidget.builder = (FlutterErrorDetails details) {
                return Scaffold(
                  body: Center(
                    child: ErrorHandler(
                      message: details.exceptionAsString(),
                      onRetry: () {
                        // Soft reset to splash
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const SplashScreen()),
                          (_) => false,
                        );
                      },
                    ),
                  ),
                );
              };
              return widget ?? const ErrorHandler();
            },
            navigatorKey: globalNavigatorKey,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('--- AuthWrapper building ---');
    }
    final firebaseUser = context.watch<AuthService>().user;
    if (kDebugMode) {
      debugPrint('--- Current user state: ${firebaseUser?.uid ?? 'Logged Out'} ---');
    }
    if (firebaseUser != null) {
      if (kDebugMode) {
        debugPrint('--- User is logged in, showing DashboardScreen ---');
      }
      // Check if onboarding/welcome tour is needed
      return FutureBuilder<Map<String, dynamic>?>(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get()
              .then((d) => d.data()),
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
          final needsOnboarding =
              !(doc?['userSetupComplete'] == true) || !hasSeenLocal;
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
    if (kDebugMode) {
      debugPrint('--- User is logged out, showing WelcomeScreen ---');
    }
    return const WelcomeScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Cloud Gray
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kin Arc logo
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: 96,
                height: 96,
                child: SvgPicture.asset(
                  AppConstants.brandLogoAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Optional subtle loading indicator
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
