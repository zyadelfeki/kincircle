import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sensory_regulation_service.dart';
import '../../design/biophilic_design.dart';
import '../../design/dark_academia_theme.dart';
import '../../design/embodied_gestures.dart';

/// Sensory controls screen for neurodivergent users
class SensoryControlsScreen extends StatefulWidget {
  const SensoryControlsScreen({super.key});

  @override
  State<SensoryControlsScreen> createState() => _SensoryControlsScreenState();
}

class _SensoryControlsScreenState extends State<SensoryControlsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SensoryRegulationService>(
      builder: (context, sensoryService, _) {
        final profile = sensoryService.profile;
        final isDarkAcademia = profile.darkAcademiaMode;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Your Comfort Zone',
              style: isDarkAcademia
                  ? const TextStyle(fontFamily: 'Crimson Text')
                  : null,
            ),
            leading: TactileIconButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).pop(),
              enableHaptics: sensoryService.shouldUseHaptics,
            ),
          ),
          body: _buildBody(context, sensoryService, profile, isDarkAcademia),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    if (service.calmModeActive) {
      return _buildCalmModeInterface(context, service);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(service.getPadding(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAgeInput(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildMotionControls(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildSoundControls(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildVisualControls(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildQuickModes(context, service, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildBreakReminders(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildThemeToggle(context, service, profile, isDarkAcademia),
          SizedBox(height: service.getPadding(24)),
          _buildEmergencyCalmMode(context, service, isDarkAcademia),
        ],
      ),
    );
  }

  Widget _buildAgeInput(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    final ageController = TextEditingController(
      text: profile.familyMemberAge?.toString() ?? '',
    );

    String getAgeProfileDescription(int? age) {
      if (age == null) return 'Enter age to auto-configure comfort settings';
      if (age < 25) return 'Young profile: High stimulation, reduced motion, high contrast';
      if (age > 60) return 'Elderly profile: Low stimulation, large text, breathing space';
      return 'Standard profile: Balanced settings';
    }

    final cardWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cake, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Family Member Age',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'Enter age',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) async {
                  final age = int.tryParse(value);
                  if (age != null && age > 0 && age < 120) {
                    if (service.shouldUseHaptics) {
                      TactileFeedback.softButton();
                    }
                    await service.applyAgeBasedProfile(age);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile updated for age $age'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                final age = int.tryParse(ageController.text);
                if (age != null && age > 0 && age < 120) {
                  if (service.shouldUseHaptics) {
                    TactileFeedback.softButton();
                  }
                  await service.applyAgeBasedProfile(age);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile updated for age $age'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          getAgeProfileDescription(profile.familyMemberAge),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    if (isDarkAcademia) {
      return VintageCard(child: cardWidget);
    } else if (profile.stimulationLevel < 0.5) {
      return BiophilicCard(child: cardWidget);
    }
    return SensoryCard(
      enableHaptics: service.shouldUseHaptics,
      child: cardWidget,
    );
  }

  Widget _buildMotionControls(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'MOTION',
      child: SwitchListTile(
        title: const Text('Reduce Motion'),
        subtitle: const Text('Calmer, slower animations'),
        value: profile.reduceMotion,
        onChanged: (value) async {
          if (service.shouldUseHaptics) {
            await TactileFeedback.satisfyingClick();
          }
          await service.setReduceMotion(value);
        },
      ),
    );
  }

  Widget _buildSoundControls(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'SOUND',
      child: SwitchListTile(
        title: const Text('Quiet Mode'),
        subtitle: const Text('Visual feedback only, no haptics'),
        value: profile.quietMode,
        onChanged: (value) async {
          if (!value && service.shouldUseHaptics) {
            await TactileFeedback.satisfyingClick();
          }
          await service.setQuietMode(value);
        },
      ),
    );
  }

  Widget _buildVisualControls(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'VISUAL',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('High Contrast'),
            subtitle: const Text('Easier to read, clearer text'),
            value: profile.highContrast,
            onChanged: (value) async {
              if (service.shouldUseHaptics) {
                TactileFeedback.softButton();
              }
              await service.setHighContrast(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Breathing Space'),
            subtitle: const Text('Extra padding, less crowded'),
            value: profile.breathingSpace,
            onChanged: (value) async {
              if (service.shouldUseHaptics) {
                TactileFeedback.softButton();
              }
              await service.setBreathingSpace(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickModes(
    BuildContext context,
    SensoryRegulationService service,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'QUICK COMFORT MODES',
      child: SizedBox(
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildQuickModeButton(
                context,
                service,
                isDarkAcademia,
                icon: '🧘',
                label: 'Calm',
                onPressed: () async {
                  if (service.shouldUseHaptics) {
                    await TactileFeedback.satisfyingClick();
                  }
                  await service.applyCalmMode();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calm mode activated')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildQuickModeButton(
                context,
                service,
                isDarkAcademia,
                icon: '🎯',
                label: 'Focus',
                onPressed: () async {
                  if (service.shouldUseHaptics) {
                    await TactileFeedback.satisfyingClick();
                  }
                  await service.applyFocusMode();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Focus mode activated')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildQuickModeButton(
                context,
                service,
                isDarkAcademia,
                icon: '⚡',
                label: 'Energy',
                onPressed: () async {
                  if (service.shouldUseHaptics) {
                    await TactileFeedback.satisfyingClick();
                  }
                  await service.applyEnergyMode();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Energy mode activated')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickModeButton(
    BuildContext context,
    SensoryRegulationService service,
    bool isDarkAcademia,
    {required String icon, required String label, required VoidCallback onPressed}
  ) {
    if (isDarkAcademia) {
      return BrassButton(
        text: '$icon $label',
        onPressed: onPressed,
      );
    } else if (service.useBiophilicDesign()) {
      return NatureButton(
        text: '$icon $label',
        onPressed: onPressed,
      );
    }
    return TactileButton(
      text: '$icon $label',
      onPressed: onPressed,
      enableHaptics: service.shouldUseHaptics,
    );
  }

  Widget _buildBreakReminders(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'BREAK REMINDERS',
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Enabled (Every ${profile.breakInterval} min)'),
            subtitle: const Text('Gentle nudges to rest'),
            value: profile.breakRemindersEnabled,
            onChanged: (value) async {
              if (service.shouldUseHaptics) {
                TactileFeedback.softButton();
              }
              await service.setBreakReminders(value);
            },
          ),
          if (profile.breakRemindersEnabled) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Text('Interval: ')),
                  Expanded(
                    child: Slider(
                      value: profile.breakInterval.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '${profile.breakInterval} min',
                      onChanged: (value) async {
                        if (service.shouldUseHaptics) {
                          TactileFeedback.softButton();
                        }
                        await service.setBreakReminders(
                          true,
                          interval: value.toInt(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeToggle(
    BuildContext context,
    SensoryRegulationService service,
    SensoryProfile profile,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'THEME',
      child: SwitchListTile(
        title: const Text('Dark Academia Mode'),
        subtitle: const Text('Vintage, moody, scholarly aesthetic'),
        value: profile.darkAcademiaMode,
        onChanged: (value) async {
          if (service.shouldUseHaptics) {
            await TactileFeedback.satisfyingClick();
          }
          await service.setDarkAcademiaMode(value);
        },
      ),
    );
  }

  Widget _buildEmergencyCalmMode(
    BuildContext context,
    SensoryRegulationService service,
    bool isDarkAcademia,
  ) {
    return _buildControlSection(
      context,
      service,
      isDarkAcademia,
      title: 'EMERGENCY',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Feeling overwhelmed? Tap for minimal interface.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                service.activateCalmMode();
                if (service.shouldUseHaptics) {
                  TactileFeedback.gentleNotification();
                }
              },
              icon: const Icon(Icons.spa),
              label: const Text('Emergency Calm Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    SensoryRegulationService service,
    bool isDarkAcademia, {
    required String title,
    required Widget child,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
      ],
    );

    if (isDarkAcademia) {
      return VintageCard(child: content);
    } else if (service.useBiophilicDesign()) {
      return BiophilicCard(child: content);
    }
    return SensoryCard(
      enableHaptics: service.shouldUseHaptics,
      child: content,
    );
  }

  Widget _buildCalmModeInterface(
    BuildContext context,
    SensoryRegulationService service,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.spa, size: 80, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              'Take a Deep Breath',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'re safe. Everything is okay.\nTake your time.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                service.deactivateCalmMode();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('I\'m Ready'),
            ),
          ],
        ),
      ),
    );
  }

}
