import 'package:flutter/material.dart';

import '../../services/remote_config_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final RemoteConfigService _rc = RemoteConfigService();
  bool? _silenceEnabled;
  bool? _voiceSosEnabled;

  @override
  void initState() {
    super.initState();
    _silenceEnabled = _rc.silenceEnabled;
    _voiceSosEnabled = _rc.voiceSosEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI & Smart Features')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Context-Aware Smart Silence'),
            subtitle: const Text(
                "Automatically silences non-critical alerts when you're likely asleep."),
            value: _silenceEnabled ?? false,
            onChanged: (val) async {
              setState(() => _silenceEnabled = val);
              await _rc.setSilenceEnabled(val);
            },
          ),
          SwitchListTile(
            title: const Text('Enable Voice-Triggered SOS'),
            subtitle: const Text(
                'Allows you to send an SOS alert using a voice command.'),
            value: _voiceSosEnabled ?? false,
            onChanged: (val) async {
              setState(() => _voiceSosEnabled = val);
              await _rc.setVoiceSosEnabled(val);
            },
          ),
        ],
      ),
    );
  }
}
