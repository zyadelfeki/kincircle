import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_controller.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  String _currentPlan = 'Free';
  bool _processing = false;
  bool _annual = false;

  Future<void> _changePlan(String plan) async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      _processing = false;
    });
    await context.read<ThemeController>().setPro(plan == 'Pro');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to $plan plan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your plan', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Monthly'),
                Switch(value: _annual, onChanged: (v) => setState(() => _annual = v)),
                const Text('Annual'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PlanCard(
                    title: 'Free',
                    price: '0',
                    period: '/forever',
                    features: const [
                      'Location sharing',
                      '2 places alerts',
                    ],
                    selected: _currentPlan == 'Free',
                    onTap: _processing ? null : () => _changePlan('Free'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlanCard(
                    title: 'Pro',
                    price: _annual ? '59.99' : '5.99',
                    period: _annual ? '/year' : '/month',
                    features: const [
                      'Unlimited places alerts',
                      'AI Smart Alerts',
                      'Priority support',
                    ],
                    selected: _currentPlan == 'Pro',
                    onTap: _processing ? null : () => _changePlan('Pro'),
                    isHighlighted: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _processing ? null : () => _changePlan(_currentPlan == 'Pro' ? 'Free' : 'Pro'),
                child: _processing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_currentPlan == 'Pro' ? 'Downgrade to Free' : 'Upgrade to Pro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.selected,
    this.isHighlighted = false,
    this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool selected;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Card(
  color: isHighlighted ? scheme.primary.withValues(alpha: 0.06) : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (selected) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                    Text(
                      '\$$price',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(width: 4),
                  Text(period, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              for (final f in features) ...[
                Row(children: [const Icon(Icons.check, size: 16), const SizedBox(width: 6), Expanded(child: Text(f))]),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
