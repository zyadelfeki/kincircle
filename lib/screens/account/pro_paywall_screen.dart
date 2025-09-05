import 'package:flutter/material.dart';
import '../../services/purchase_service.dart';

class ProPaywallScreen extends StatelessWidget {
  const ProPaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KinCircle Pro')),
      body: Stack(
        children: [
      ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const _HeroHeadline(),
        const _BenefitCarousel(),
              const _PricingBlock(),
              const _SocialProof(),
              const _FaqBlock(),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + 8,
            child: FilledButton(
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              onPressed: () async {
                // Prefer annual by default
                try {
                  final service = PurchaseService()..init();
                  await service.buyAnnual();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purchase failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Start Your 14-Day Free Trial'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete Peace of Mind for Your Family', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          const Text('Unlimited Circle members, unlimited Safe Zones, Driving Safety reports, Crisis Mode and more.'),
        ],
      ),
    );
  }
}

class _BenefitCarousel extends StatefulWidget {
  const _BenefitCarousel();
  @override
  State<_BenefitCarousel> createState() => _BenefitCarouselState();
}

class _BenefitCarouselState extends State<_BenefitCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _index = 0;
  final _items = const [
    ('Live Location', 'See where your loved ones are in real time'),
    ('Safe Zones', 'Get notified when family arrives and leaves'),
    ('Driving Safety', 'Weekly driving reports and incident insights'),
    ('Crisis Mode', 'Broadcast your live location to your Circle'),
  ];
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
  return Column(
      children: [
  SizedBox(
          height: 160,
      child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final (title, desc) = _items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Icon(_iconFor(title), color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(title, style: Theme.of(context).textTheme.titleMedium),
                        ]),
                        const SizedBox(height: 8),
            Text(desc),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (int i = 0; i < _items.length; i++) _Dot(active: i == _index)],
        ),
      ],
    );
  }
}

IconData _iconFor(String title) {
  switch (title) {
    case 'Live Location':
      return Icons.location_on;
    case 'Safe Zones':
      return Icons.shield_moon_outlined;
    case 'Driving Safety':
      return Icons.safety_check;
    case 'Crisis Mode':
      return Icons.sos;
    default:
      return Icons.star;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
  final c = Theme.of(context).colorScheme.primary;
  return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      width: active ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
    color: active ? c : c.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PricingBlock extends StatelessWidget {
  const _PricingBlock();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Simple, transparent pricing', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _priceCard(context, title: 'Monthly', price: '\$5.99', subtitle: 'Billed monthly')),
              const SizedBox(width: 12),
              Expanded(child: _priceCard(context, title: 'Annual', price: '\$59.99', subtitle: 'Best Value • Just \$4.99/month')),
            ],
          ),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.lock_clock, size: 18),
            SizedBox(width: 6),
            Expanded(child: Text('Your trial is free for 14 days. Cancel anytime in Settings.')),
          ]),
        ],
      ),
    );
  }

  Widget _priceCard(BuildContext context, {required String title, required String price, required String subtitle}) {
  final scheme = Theme.of(context).colorScheme;
    final isAnnual = title == 'Annual';
    return Card(
      color: isAnnual ? scheme.primary.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(title, style: Theme.of(context).textTheme.titleMedium), if (isAnnual) ...[const SizedBox(width: 8), const Chip(label: Text('Best Value'))]]),
            const SizedBox(height: 8),
            Text(price, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: scheme.primary)),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _SocialProof extends StatelessWidget {
  const _SocialProof();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Families love KinCircle', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const _Testimonial(text: '“The Safe Zones make school pickups effortless.” – Maya R.'),
          const _Testimonial(text: '“Driver Safety insights helped my teen become a better driver.” – Alex T.'),
          const _Testimonial(text: '“Crisis Mode gave us peace of mind during a storm.” – Priya S.'),
        ],
      ),
    );
  }
}

class _Testimonial extends StatelessWidget {
  const _Testimonial({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}

class _FaqBlock extends StatelessWidget {
  const _FaqBlock();
  @override
  Widget build(BuildContext context) {
  const faqs = [
      ('How does the free trial work?', 'You can try all Pro features free for 14 days. Cancel anytime in Settings.'),
      ('Can I cancel any time?', 'Yes, you can cancel your subscription at any time from Settings.'),
      ('Does everyone in my family need Pro?', 'Only the family organizer needs Pro. Everyone in your Circle benefits.'),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frequently Asked Questions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          for (final (q, a) in faqs)
            Card(
              child: ExpansionTile(title: Text(q), children: [
                Padding(padding: const EdgeInsets.all(16), child: Text(a)),
              ]),
            ),
        ],
      ),
    );
  }
}
