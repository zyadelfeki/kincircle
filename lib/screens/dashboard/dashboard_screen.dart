import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/pro_gating_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart'; // Unused; firebase_auth covers used types
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:math' as math;

import '../../services/location_service.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/frosted_panel.dart';
import '../alerts/alert_details_screen.dart';
import '../driver_safety/driver_safety_summary_screen.dart';
// Removed unused keep_alive import
import '../../widgets/empty_state.dart';
import '../../services/ui_prefs.dart';
import '../../widgets/error_handler.dart';
import '../../widgets/elderly_ui_wrapper.dart';
import '../../services/age_detection_service.dart';
import '../../services/sensory_regulation_service.dart';
import '../../design/biophilic_design.dart';
import '../../widgets/companion_widgets.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Disable presence orbs (colored map dots) to avoid the "confetti" effect.
  static const bool _presenceOrbsEnabled = false;
  final LocationService _locationService = LocationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  bool _updatingVisibility = false;

  // Removed unused page controller and index

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  GoogleMapController? _mapController; // used upon map created
  Stream<List<AppUser>>? _familyLocationStream;
  String? _familyName;
  int _unseenAlerts = 0;
  bool _hintedDrag = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _initialSheetSize = 0.11;
  double _mapBottomPadding = 0;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _alertSubscription;
  int _lastMarkerCount = 0;
  bool _recentlyMarkedVisibleAlerts = false;
  DateTime _lastSheetUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  // Dock position is derived from sheet size; no separate visibility toggle needed.
  bool _fanLeft = false; // actual applied direction
  bool _fanLeftTarget = false; // last requested direction
  Timer? _fanFlipDebounce; // throttles direction flips
  double _labelOpacity = 1.0;
  Timer? _labelFadeTimer;
  bool _labelSeen = false;

  static const String _kFabLabelSeenKey = 'fab_actions_label_seen';
  static const String _kFabLabelDisabledKey = 'fab_actions_label_disabled';
  static const String _kFabTipVersionKey = 'fab_actions_tip_version';
  bool _labelDisabled = false;
  // Context & quick wins state
  double? _lastSpeedMps; // from geolocator
  bool get _isDrivingContext => (_lastSpeedMps ?? 0) >= 8.33; // ~30 km/h
  bool _showPermissionTile = false;
  // Presence orbs pulse
  double _pulseT = 0.0;
  Timer? _pulseTimer;
  // Family gating
  bool _hasFamily = false;
  // Incognito timer
  DateTime? _incognitoUntil;
  Timer? _incognitoTimer;

  // Safely read the sheet size or fall back to the last known/initial size.
  double get _safeSheetSize => (mounted && _sheetController.isAttached)
      ? _sheetController.size
      : _initialSheetSize;

  @override
  void initState() {
    super.initState();
    _loadFabLabelSeen();
    _maybeGateTipByVersion();
    // Load last sheet size and update initial size
    UiPrefs().getLastSheetSize(fallback: 0.11).then((v) {
      if (!mounted) return;
      setState(() => _initialSheetSize = v.clamp(0.11, 0.92));
    });
    // Listen for sheet size changes to save preference and adjust map padding
    _sheetController.addListener(() {
      // Throttle updates to ~30fps max
      final now = DateTime.now();
      if (now.difference(_lastSheetUpdate).inMilliseconds < 33) {
        return;
      }
      _lastSheetUpdate = now;
      if (!mounted || !_sheetController.isAttached) {
        return; // Safety: controller must be attached
      }
      final size = _sheetController.size;
      // Persist occasionally
      UiPrefs().setLastSheetSize(size);
      // Update map padding
      final height = MediaQuery.of(context).size.height;
      final target = (size * height) - 24; // account for rounded corners/handle
      // Schedule state after current frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _mapBottomPadding = target.clamp(0, height * 0.92);
        });
      });

      // Decide desired chip fan direction with RTL + width awareness
      bool computeDesiredFanLeft() {
        final width = MediaQuery.of(context).size.width;
        final isRTL = Directionality.of(context) == TextDirection.rtl;
        // Prefer left fan when sheet is tall; be a bit more eager on narrow screens
        bool desired = size > (width < 380 ? 0.6 : 0.7);
        if (isRTL) desired = !desired; // mirror for RTL
        return desired;
      }

      final desiredLeft = computeDesiredFanLeft();
      if (desiredLeft != _fanLeftTarget) {
        _fanLeftTarget = desiredLeft;
        _fanFlipDebounce?.cancel();
        _fanFlipDebounce = Timer(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          // Re-evaluate after debounce window to avoid jitter
          final stillDesired = computeDesiredFanLeft();
          if (stillDesired == _fanLeftTarget) {
            setState(() => _fanLeft = stillDesired);
          }
        });
      }

      // Collapsed label fade behavior
      if (size <= 0.12) {
        _labelFadeTimer?.cancel();
        if (_labelSeen) {
          if (_labelOpacity != 0.35) setState(() => _labelOpacity = 0.35);
        } else {
          if (_labelOpacity != 1.0) setState(() => _labelOpacity = 1.0);
          _labelFadeTimer = Timer(const Duration(seconds: 3), () async {
            if (!mounted) return;
            setState(() => _labelOpacity = 0.35);
            _labelSeen = true;
            try {
              final p = await SharedPreferences.getInstance();
              await p.setBool(_kFabLabelSeenKey, true);
            } catch (_) {}
          });
        }
      } else {
        if (!_labelSeen && _labelOpacity != 1.0) {
          setState(() => _labelOpacity = 1.0);
        }
        _labelFadeTimer?.cancel();
      }

      // When the sheet is expanded to half or more, mark visible alerts as read once per expansion.
      if (size >= 0.5 && !_recentlyMarkedVisibleAlerts) {
        _markVisibleAlertsAsRead();
        _recentlyMarkedVisibleAlerts = true;
        HapticFeedback.selectionClick();
      }
      if (size < 0.5) {
        _recentlyMarkedVisibleAlerts = false;
      }
    });
    _initLocationTracking();
    _setupFamilyLocationStream();

    // Start pulse animation for presence orbs (disabled when _presenceOrbsEnabled is false)
    if (_presenceOrbsEnabled) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (!mounted) return;
        setState(() {
          _pulseT = (_pulseT + 1) % 2; // 0 -> 1 -> 0 pattern
        });
      });
    }

    // Listen for alerts for current user to update unseen count
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _alertSubscription = _firestore
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final unseen = snapshot.docs.where((d) {
          final data = d.data();
          return data['seen'] != true;
        }).length;
        if (_unseenAlerts != unseen) {
          setState(() => _unseenAlerts = unseen);
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _userDocSubscription?.cancel();
    _alertSubscription?.cancel();
    _mapController?.dispose();
    _fanFlipDebounce?.cancel();
    _labelFadeTimer?.cancel();
    _pulseTimer?.cancel();
    _incognitoTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _maybeGateTipByVersion() async {
    try {
      final p = await SharedPreferences.getInstance();
      final pkg = await PackageInfo.fromPlatform();
      final currentVersion = '${pkg.version}+${pkg.buildNumber}';
      final lastVersion = p.getString(_kFabTipVersionKey);
      if (lastVersion == null || lastVersion != currentVersion) {
        // New version detected: reshow tip (unless user explicitly disabled via settings)
        final disabled = p.getBool(_kFabLabelDisabledKey) ?? false;
        if (!disabled) {
          await p.setBool(_kFabLabelSeenKey, false);
          if (mounted) {
            setState(() {
              _labelSeen = false;
              _labelOpacity = 1.0;
            });
          }
        }
        await p.setString(_kFabTipVersionKey, currentVersion);
      }
    } catch (_) {}
  }

  Future<void> _loadFabLabelSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      final seen = p.getBool(_kFabLabelSeenKey) ?? false;
      final disabled = p.getBool(_kFabLabelDisabledKey) ?? false;
      if (mounted) {
        setState(() {
          _labelSeen = seen;
          _labelDisabled = disabled;
          _labelOpacity = (seen || disabled) ? 0.35 : 1.0;
        });
      }
    } catch (_) {}
  }

  Future<void> _markVisibleAlertsAsRead() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final q = _firestore
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(10);
      final snap = await q.get();
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        final data = d.data();
        final seen = (data['seen'] as bool?) ?? false;
        if (!seen) {
          batch.set(d.reference, {'seen': true}, SetOptions(merge: true));
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _initLocationTracking() async {
    try {
      bool hasPermission = await _locationService.requestPermission();
      if (hasPermission) {
        _positionSubscription = _locationService.startLocationUpdates().listen(
          (position) {
            _lastSpeedMps = position.speed;
            _locationService.updateUserLocation(position);
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _error = 'Error tracking location: $error';
            });
          },
        );
        if (mounted) setState(() => _showPermissionTile = false);
      } else {
        if (!mounted) return;
        setState(() {
          _showPermissionTile = true;
          _error = null; // calm UI, show tile instead
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error initializing location: $e';
      });
    }
  }

  Future<void> _setupFamilyLocationStream() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      _userDocSubscription = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen(
        (userDoc) {
          if (!mounted) return;
          final familyId = userDoc.data()?['currentFamilyId'];
          if (familyId == null) {
            setState(() {
              _familyLocationStream =
                  Stream<List<AppUser>>.value(const <AppUser>[])
                      .asBroadcastStream();
              _isLoading = false;
              _hasFamily = false;
            });
            return;
          }
          _listenToFamily(familyId);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = 'Error fetching user data: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error setting up family stream: $e';
        _isLoading = false;
      });
    }
  }

  void _listenToFamily(String familyId) async {
    try {
      final familyDoc =
          await _firestore.collection('families').doc(familyId).get();
      if (!familyDoc.exists) {
        if (!mounted) return;
        setState(() {
          _error = 'Family not found';
          _isLoading = false;
        });
        return;
      }

      final docFamilyId = familyDoc.id;
      final name = familyDoc.data()?['name'] as String?;

      if (!mounted) return;
      setState(() {
        _familyLocationStream = _firestore
            .collection('users')
            .where('currentFamilyId', isEqualTo: docFamilyId)
            .snapshots()
            .map((snapshot) =>
                snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList())
            .asBroadcastStream();
        _familyName =
            (name != null && name.trim().isNotEmpty) ? name.trim() : null;
        _isLoading = false;
        _hasFamily = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching family data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageDetection = Provider.of<AgeDetectionService>(context);
    final sensoryService = Provider.of<SensoryRegulationService>(context);
    
    // Track interaction for age detection
    ageDetection.startSession();
    
    final Widget scaffoldContent = Scaffold(
      appBar: AppBar(
        title: const Text('Kin Arc'),
        actions: [
            IconButton(
              icon: const Icon(Icons.safety_check),
              onPressed: () async {
                ageDetection.recordTap();
                final allowed = await ProGatingService()
                    .ensureProFeature(context, 'Driver Safety Reports');
                if (allowed && context.mounted) {
                  Navigator.of(context).pushNamed('/driver-safety');
                }
              },
              tooltip: 'Driver Safety',
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                ageDetection.recordTap();
                Navigator.of(context)
                    .pushNamed(_hasFamily ? '/invite' : '/create-family');
              },
              tooltip: _hasFamily ? 'Invite Members' : 'Create Family',
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                ageDetection.recordTap();
                Navigator.of(context).pushNamed('/help');
              },
              tooltip: 'Help',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                ageDetection.recordTap();
                Navigator.of(context).pushNamed('/settings');
              },
              tooltip: 'Settings',
            ),
            // Log Out is available in Settings; keep app bar focused
          ],
        ),
        body: Stack(
          children: [
            // Base layer: full-screen Google Map with overlays
          Positioned.fill(child: _buildMapPage()),
          // Family Sheet: layered contextual info
          _buildFamilySheet(),
          // Docked FAB that sits above the sheet top edge
          _buildDockedFab(context),
          if (_showPermissionTile) _buildPermissionTile(context),
        ],
      ),
      // floatingActionButton removed in favor of docked positioning within the Stack
    );

    // Apply biophilic design overlay if stimulation level is low
    Widget wrappedContent = scaffoldContent;
    if (sensoryService.useBiophilicDesign()) {
      wrappedContent = Stack(
        children: [
          scaffoldContent,
          // Nature pattern overlay
          const Positioned.fill(
            child: IgnorePointer(
              child: NaturePatternOverlay(
                opacity: 0.05,
              ),
            ),
          ),
        ],
      );
    }

    return ElderlyUIWrapper(
      child: wrappedContent,
    );
  }

  Widget _buildPermissionTile(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 80,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.my_location, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable location to see your family on the map and get smart alerts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await _initLocationTracking();
                },
                child: const Text('Enable'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockedFab(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // Bottom offset equals sheet height + margin so the FAB hugs the sheet edge.
    double bottom = _safeSheetSize * height + 16;
    // Keep within a safe visual zone (avoid getting too high near app bar)
    final maxBottom = height - 220; // ~ keep 220px from top
    bottom = bottom.clamp(16.0, maxBottom);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      right: 16,
      bottom: bottom,
      child: _ExpandableFab(
        fanLeft: _fanLeft,
        showCollapsedLabel: false,
        collapsedLabel: '',
        collapsedLabelOpacity: _labelOpacity,
        edgeBottom: MediaQuery.of(context).padding.bottom,
        onCollapsedLabelTap: () async {
          // Make the label act as a trigger to open actions; long-press on FAB can hide tip in Settings.
          // No-op if disabled.
          if (_labelDisabled) return;
          // Programmatically expand by tapping the FAB via a global key if desired; simplest: do nothing here.
          // The label is positioned right next to the FAB; users can tap FAB to open.
        },
        children: _getAdaptiveActions(),
      ),
    );
  }

  // Draggable bottom sheet with collapsed/half/full states
  Widget _buildFamilySheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialSheetSize,
      minChildSize: 0.11,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.11, 0.5, 0.92],
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: _hintedDrag ? 1.0 : 0.9, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                onEnd: () => _hintedDrag = true,
                builder: (context, value, _) => Transform.scale(
                  scale: value,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Collapsed / summary line (tap to toggle)
              InkWell(
                onTap: () {
                  if (!mounted || !_sheetController.isAttached) return;
                  final size = _sheetController.size;
                  final target = size < 0.2 ? 0.5 : 0.11;
                  if (mounted && _sheetController.isAttached) {
                    _sheetController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
                onLongPress: () async {
                  // Rename family
                  if (_familyName == null) return;
                  final controller = TextEditingController(text: _familyName);
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Rename Family'),
                      content: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(hintText: 'Family name'),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text.trim()),
                            child: const Text('Save')),
                      ],
                    ),
                  );
                  if (newName != null && newName.isNotEmpty) {
                    try {
                      // Find current family id via any member doc
                      final members = await _familyLocationStream?.first;
                      final famId = members?.first.currentFamilyId;
                      if (famId != null) {
                        await _firestore
                            .collection('families')
                            .doc(famId)
                            .set({'name': newName}, SetOptions(merge: true));
                        if (mounted) {
                          setState(() => _familyName = newName);
                        }
                      }
                    } catch (_) {}
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.family_restroom_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StreamBuilder<List<AppUser>>(
                          stream: _familyLocationStream,
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length ?? 0;
                            final title =
                                (_familyName == null || _familyName!.isEmpty)
                                    ? 'Your Family'
                                    : _familyName!;
                            final summary = count > 0
                                ? '$title • $count members safe'
                                : title;
                            // Online badge: green dot when any member updated within last 10 minutes
                            final now = DateTime.now();
                            final hasRecent =
                                (snapshot.data ?? const <AppUser>[]).any((u) =>
                                    u.lastUpdated != null &&
                                    now.difference(u.lastUpdated!).inMinutes <=
                                        10);
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (hasRecent)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Avatars preview or Invite CTA when no members
                      SizedBox(
                        width: 92,
                        height: 28, // Ensure finite height for Stack below
                        child: StreamBuilder<List<AppUser>>(
                          stream: _familyLocationStream,
                          builder: (context, snapshot) {
                            final members =
                                (snapshot.data ?? const <AppUser>[]);
                            if (!_hasFamily) {
                              return OutlinedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('/create-family'),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(72, 32),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8)),
                                child: const Text('Create'),
                              );
                            }
                            if (members.isEmpty) {
                              return OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pushNamed('/invite'),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(72, 32),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8)),
                                child: const Text('Invite'),
                              );
                            }
                            final show = members.take(3).toList();
                            return Stack(
                              children: [
                                for (var i = 0; i < show.length; i++)
                                  Positioned(
                                    left: i * 22.0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundImage:
                                          show[i].photoURL.isNotEmpty
                                              ? NetworkImage(show[i].photoURL)
                                              : null,
                                      child: show[i].photoURL.isEmpty
                                          ? const Icon(Icons.person, size: 14)
                                          : null,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Alerts chip
                      if (_unseenAlerts > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Alerts: $_unseenAlerts',
                              style: Theme.of(context).textTheme.labelMedium),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Scrollable content for half/full states
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    100.0 + ((_safeSheetSize > 0.7) ? 52.0 : 0.0),
                  ),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    const CompanionDashboardWidget(),
                    const SizedBox(height: 12),
                    _buildRecapCard(),
                    const SizedBox(height: 12),
                    _buildDriverSafetyCard(),
                    const SizedBox(height: 12),
                    // Family list
                    _buildFamilyListSection(),
                    const SizedBox(height: 12),
                    // Alerts history
                    Text('Alerts History',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(height: 260, child: _buildAlertsListCompact()),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/alerts'),
                        icon: const Icon(Icons.more_horiz),
                        label: const Text('More'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed('/settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFamilyListSection() {
    return SizedBox(
      height: 240,
      child: StreamBuilder<List<AppUser>>(
        stream: _familyLocationStream,
        builder: (context, snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final members = snapshot.data ?? const <AppUser>[];
          if (members.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.people_outline,
              headline: 'No family yet',
              description: 'Invite your family to see everyone here.',
              actionLabel: 'Invite',
              onAction: () => Navigator.of(context).pushNamed('/invite'),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = members[index];
              return SizedBox(
                width: 260,
                child: Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: m.photoURL.isNotEmpty
                          ? NetworkImage(m.photoURL)
                          : null,
                      child:
                          m.photoURL.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(
                        m.displayName.isNotEmpty ? m.displayName : 'Member'),
                    subtitle:
                        Text('Updated: ${_formatLastUpdated(m.lastUpdated)}'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertsListCompact() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('No user'));
    final alertsQuery = _firestore
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(10);

    return StreamBuilder<QuerySnapshot>(
      stream: alertsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final err = snapshot.error;
          if (err is FirebaseException && err.code == 'failed-precondition') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ErrorHandler(
                  message:
                      'Database setup required. Please ask the account administrator to create the necessary index in the Firebase console.',
                  onRetry: () {
                    // Defer rebuild to next frame to avoid setState during StreamBuilder build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              ),
            );
          }
          return const Center(child: Text('Unable to load alerts'));
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.notifications_none,
            headline: 'No alerts yet',
            description: 'Your recent alerts will appear here.',
          );
        }
        return ListView.separated(
          primary: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final d = docs[index];
            final data = d.data() as Map<String, dynamic>? ?? {};
            final title = data['title'] as String? ?? 'Alert';
            final message = data['message'] as String? ?? '';
            return ListTile(
              leading: const Icon(Icons.notification_important),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle:
                  Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AlertDetailsScreen(alertId: d.id, alertData: data),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMapPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                _initLocationTracking();
                _setupFamilyLocationStream();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<AppUser>>(
      stream: _familyLocationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final familyMembers = snapshot.data!;
        final Set<Marker> markers = familyMembers
            .where(
                (user) => !user.isInvisible && user.lastKnownLocation != null)
            .map((user) {
          return Marker(
            markerId: MarkerId(user.uid),
            position: user.lastKnownLocation!,
            infoWindow: InfoWindow(
              title: user.displayName,
              snippet: 'Last updated: ${_formatLastUpdated(user.lastUpdated)}',
            ),
          );
        }).toSet();

        // Presence orbs as circles (disabled)
        final Set<Circle> circles = _presenceOrbsEnabled
            ? familyMembers
                .where((u) => !u.isInvisible && u.lastKnownLocation != null)
                .map((u) {
                final now = DateTime.now();
                final mins = u.lastUpdated != null
                    ? now.difference(u.lastUpdated!).inMinutes
                    : 999;
                Color base = Colors.blue;
                if (mins <= 10) {
                  base = Colors.green;
                } else if (mins > 60) {
                  base = Colors.orange;
                }
                final radius = 35 + 10 * math.sin((_pulseT) * math.pi);
                return Circle(
                  circleId: CircleId('orb_${u.uid}'),
                  center: u.lastKnownLocation!,
                  radius: radius.toDouble(),
                  strokeColor: base.withValues(alpha: 0.0),
                  fillColor: base.withValues(alpha: 0.20),
                );
              }).toSet()
            : <Circle>{};

        // Find a valid initial position
        final initialPosition = familyMembers
                .firstWhere(
                  (m) => m.lastKnownLocation != null,
                  orElse: () => familyMembers.first,
                )
                .lastKnownLocation ??
            const LatLng(31.4175, 30.3662); // Default to Rosetta, Egypt

        // Animate camera to fit markers when data changes
        if (_mapController != null &&
            markers.isNotEmpty &&
            (_lastMarkerCount != markers.length)) {
          _lastMarkerCount = markers.length;
          final bounds =
              _computeBounds(markers.map((m) => m.position).toList());
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 64),
            );
          });
        }

        // Build stack to overlay invisible switch
        return Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 14,
              ),
              markers: markers,
              circles: circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              padding: EdgeInsets.only(bottom: _mapBottomPadding),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: FrostedPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInvisibleSwitch(familyMembers),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: _incognitoUntil == null
                            ? 'Incognito'
                            : 'Incognito active',
                        icon: Icon(Icons.theater_comedy,
                            color:
                                _incognitoUntil == null ? null : Colors.amber),
                        onPressed: () => _showIncognitoChooser(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showIncognitoChooser(BuildContext context) async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('Go Incognito',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('15 min'),
                    selected: false,
                    onSelected: (_) =>
                        Navigator.pop(ctx, const Duration(minutes: 15))),
                ChoiceChip(
                    label: const Text('1 hour'),
                    selected: false,
                    onSelected: (_) =>
                        Navigator.pop(ctx, const Duration(hours: 1))),
                ChoiceChip(
                    label: const Text('Until tomorrow'),
                    selected: false,
                    onSelected: (_) =>
                        Navigator.pop(ctx, const Duration(hours: 12))),
              ],
            ),
            const SizedBox(height: 8),
            if (_incognitoUntil != null)
              TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _disableIncognito();
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Turn off now')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) {
      _enableIncognito(choice);
    }
  }

  Future<void> _enableIncognito(Duration d) async {
    try {
      await _firestoreService.updateVisibility(isInvisible: true);
      final until = DateTime.now().add(d);
      setState(() => _incognitoUntil = until);
      _incognitoTimer?.cancel();
      _incognitoTimer = Timer(d, _disableIncognito);
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Incognito until ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}')),
        );
      }
    } catch (_) {}
  }

  Future<void> _disableIncognito() async {
    try {
      await _firestoreService.updateVisibility(isInvisible: false);
      if (mounted) setState(() => _incognitoUntil = null);
      _incognitoTimer?.cancel();
    } catch (_) {}
  }

  Widget _buildEmptyState() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, (1 - value) * 10), child: child),
      ),
      child: _hasFamily
          ? EmptyStateWidget(
              icon: Icons.groups_outlined,
              headline: 'Your Circle is Empty',
              description:
                  'Invite your family to see everyone on the map and get smart alerts.',
              actionLabel: 'Invite Your First Family Member',
              onAction: () => Navigator.of(context).pushNamed('/invite'),
            )
          : EmptyStateWidget(
              icon: Icons.family_restroom_outlined,
              headline: 'Create Your Family',
              description:
                  'Start by creating your family, then invite members to join.',
              actionLabel: 'Create Family',
              onAction: () => Navigator.of(context).pushNamed('/create-family'),
            ),
    );
  }

  // Driver Safety Card for quick access to safety reports
  Widget _buildDriverSafetyCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DriverSafetySummaryScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.drive_eta,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver Safety',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View your weekly safety report',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Simple recap card based on recent activity
  Widget _buildRecapCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<List<AppUser>>(
          stream: _familyLocationStream,
          builder: (context, snapshot) {
            final members = snapshot.data ?? const <AppUser>[];
            final now = DateTime.now();
            final recent = members
                .where((m) =>
                    m.lastUpdated != null &&
                    now.difference(m.lastUpdated!).inMinutes <= 120)
                .length;
            String msg;
            if (members.isEmpty) {
              msg =
                  'Today at a glance: Invite your first family member to start.';
            } else if (recent == members.length) {
              msg = "Today's recap: Everyone's day is proceeding as normal.";
            } else {
              msg = 'Today\'s recap: Some members have not updated recently.';
            }
            return Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(child: Text(msg)),
              ],
            );
          },
        ),
      ),
    );
  }

  // Removed unused page builders (_buildFamilyListPage, _buildAlertsPage)

  // Helper to compute LatLngBounds from a list of points (non-nullable)
  LatLngBounds _computeBounds(List<LatLng> positions) {
    assert(positions.isNotEmpty, 'positions must not be empty');
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;
    for (final p in positions.skip(1)) {
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
      if (p.longitude < minLng) minLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Removed unused _refreshFamilyData()

  // Adaptive FAB actions by context
  List<_FabAction> _getAdaptiveActions() {
    final actions = <_FabAction>[];
    if (_isDrivingContext) {
      actions.add(_FabAction(
        icon: Icons.directions_car,
        label: 'Share ETA',
        onTap: () async {
          HapticFeedback.selectionClick();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing ETA via notification')),
            );
          }
        },
      ));
    }

    actions.add(_FabAction(
      icon: Icons.check_circle_outline,
      label: 'Check-in',
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in sent')),
        );
      },
    ));

    actions.add(_FabAction(
      icon: Icons.add_location_alt_outlined,
      label: 'Add Geofence',
      onTap: () => Navigator.of(context).pushNamed('/add-geofence'),
    ));

    actions.add(_FabAction(
      icon: Icons.sos,
      label: 'SOS',
      onTap: () async {
        final allowed = await ProGatingService().ensureProFeature(context, 'Crisis Mode');
        if (!mounted) return;
        if (allowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS sent')),
          );
        }
      },
    ));
    return actions;
  }

  // Removed confetti overlay and random dot effects by request

  Widget _buildInvisibleSwitch(List<AppUser> members) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    final currentUser = members.firstWhere(
      (u) => u.uid == currentUid,
      orElse: () => AppUser(
        uid: currentUid,
        displayName: 'You',
        photoURL: '',
        isInvisible: false,
      ),
    );

    return Row(
      children: [
        const Text('Invisible'),
        const SizedBox(width: 8),
        Switch(
          value: currentUser.isInvisible,
          onChanged: _updatingVisibility
              ? null
              : (val) async {
                  setState(() => _updatingVisibility = true);
                  try {
                    await _firestoreService.updateVisibility(isInvisible: val);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _updatingVisibility = false);
                    }
                  }
                },
        ),
      ],
    );
  }

  String _formatLastUpdated(DateTime? lastUpdated) {
    if (lastUpdated == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _ExpandableFab extends StatefulWidget {
  const _ExpandableFab({
    required this.children,
    this.fanLeft = false,
    this.showCollapsedLabel = false,
    this.collapsedLabel = 'Actions',
    this.collapsedLabelOpacity,
    this.edgeBottom = 0,
    this.onCollapsedLabelTap,
  });

  final List<_FabAction> children;
  final bool fanLeft;
  final bool showCollapsedLabel;
  final String collapsedLabel;
  final double? collapsedLabelOpacity;
  final double edgeBottom; // safe area inset
  final VoidCallback? onCollapsedLabelTap;

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expand;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
      HapticFeedback.lightImpact();
    } else {
      _controller.reverse();
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // Actions fan-out
          ...List.generate(widget.children.length, (i) {
            final action = widget.children[i];
            const base = 62.0;
            final offset = (i + 1) * (widget.fanLeft ? base + 6.0 : base);
            return AnimatedBuilder(
              animation: _expand,
              builder: (context, child) {
                return Positioned(
                  right: widget.fanLeft ? (8 + offset * _expand.value) : 0,
                  bottom: (widget.fanLeft ? 8 : (8 + offset * _expand.value)) +
                      widget.edgeBottom,
                  child: Opacity(
                    opacity: _expand.value,
                    child: Transform.scale(
                      scale: _expand.value,
                      child: _ActionChip(
                        icon: action.icon,
                        label: action.label,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          action.onTap();
                          _toggle();
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }).reversed,
          if (widget.showCollapsedLabel && !_open)
            Positioned(
              right: 72,
              bottom: 12 + widget.edgeBottom,
              child: AnimatedOpacity(
                opacity: widget.collapsedLabelOpacity ?? 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Open actions when tapping label for a clearer affordance
                      _toggle();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text(
                        widget.collapsedLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Main FAB
          FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: theme.colorScheme.primary,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child:
                  Icon(_open ? Icons.close : Icons.add, key: ValueKey(_open)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabAction {
  _FabAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
