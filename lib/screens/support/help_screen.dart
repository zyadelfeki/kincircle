import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _content = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final md = await rootBundle.loadString('docs/FAQ.md');
      if (mounted) setState(() => _content = md);
    } catch (e) {
      setState(() => _content = '# Help\nUnable to load help at the moment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _content.split('\n');
    final filtered = _query.isEmpty
        ? lines
        : lines.where((l) => l.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search help…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, i) => Text(filtered[i]),
            ),
          )
        ],
      ),
    );
  }
}
