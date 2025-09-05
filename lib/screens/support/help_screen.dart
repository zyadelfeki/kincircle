import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/support_ticket_service.dart';

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

  List<_FaqSection> _parseSections(String md) {
    final lines = md.split('\n');
    final sections = <_FaqSection>[];
  _FaqSection? current;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (current != null) sections.add(current);
        current = _FaqSection(title: line.substring(3).trim(), items: []);
      } else if (line.startsWith('### ')) {
        final title = line.substring(4).trim();
    current ??= _FaqSection(title: 'General', items: []);
        current.items.add(_FaqItem(question: title, answer: ''));
      } else if (line.trim().isNotEmpty) {
    current ??= _FaqSection(title: 'General', items: []);
        if (current.items.isEmpty) {
          current.items.add(_FaqItem(question: 'Info', answer: line.trim()));
        } else {
          final last = current.items.last;
          current.items[current.items.length - 1] =
              last.copyWith(answer: ('${last.answer}\n$line').trim());
        }
      }
    }
    if (current != null) sections.add(current);
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(_content).where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.items.any((i) =>
              i.question.toLowerCase().contains(q) ||
              i.answer.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
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
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _SectionWidget(section: section),
            ),
          const SizedBox(height: 8),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Contact Support',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ContactSupportForm(),
          ),
        ],
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.section});
  final _FaqSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(section.title),
        children: [
          for (final item in section.items) _FaqItemTile(item: item),
        ],
      ),
    );
  }
}

class _FaqItemTile extends StatefulWidget {
  const _FaqItemTile({required this.item});
  final _FaqItem item;
  @override
  State<_FaqItemTile> createState() => _FaqItemTileState();
}

class _FaqItemTileState extends State<_FaqItemTile> {
  bool? _helpful; // null = not answered, true/false after selection
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(widget.item.question,
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(widget.item.answer),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                const Text('Was this helpful?'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Yes'),
                  selected: _helpful == true,
                  onSelected: (_) => setState(() {
                    _helpful = true;
                    _showForm = false;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('No'),
                  selected: _helpful == false,
                  onSelected: (_) => setState(() {
                    _helpful = false;
                    _showForm = true;
                  }),
                ),
              ],
            ),
          ),
          if (_showForm)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _InlineContactForm(defaultSubject: widget.item.question),
            ),
          const Divider(),
        ],
      ),
    );
  }
}

class _InlineContactForm extends StatefulWidget {
  const _InlineContactForm({required this.defaultSubject});
  final String defaultSubject;
  @override
  State<_InlineContactForm> createState() => _InlineContactFormState();
}

class _InlineContactFormState extends State<_InlineContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  File? _screenshot;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _screenshot = File(xfile.path));
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final id = await SupportTicketService().createTicket(
        name: 'In-app user',
        email: _email.text.trim(),
        subject: widget.defaultSubject,
        description: _message.text.trim(),
        screenshot: _screenshot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! Ticket $id created.')),
      );
      _formKey.currentState!.reset();
      setState(() => _screenshot = null);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Your email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'What didn\'t help?'),
            minLines: 2,
            maxLines: 4,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please add a brief note'
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.attachment),
                label: const Text('Attach screenshot'),
              ),
              const SizedBox(width: 8),
              if (_screenshot != null)
                const Icon(Icons.check_circle, color: Colors.green),
              const Spacer(),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _ContactSupportForm extends StatefulWidget {
  @override
  State<_ContactSupportForm> createState() => _ContactSupportFormState();
}

class _ContactSupportFormState extends State<_ContactSupportForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  File? _screenshot;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _screenshot = File(xfile.path));
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final id = await SupportTicketService().createTicket(
        name: _name.text,
        email: _email.text,
        subject: _subject.text.isNotEmpty ? _subject.text : 'Support Request',
        description: _message.text,
        screenshot: _screenshot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket $id created. We’ll reply within 24 hours.')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _screenshot = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Your email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'How can we help?'),
            minLines: 3,
            maxLines: 5,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter a message'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.attachment),
                label: const Text('Attach screenshot'),
              ),
              const SizedBox(width: 8),
              if (_screenshot != null)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _FaqSection {
  _FaqSection({required this.title, required this.items});
  final String title;
  final List<_FaqItem> items;
}

class _FaqItem {
  _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
  _FaqItem copyWith({String? question, String? answer}) => _FaqItem(
      question: question ?? this.question, answer: answer ?? this.answer);
}
