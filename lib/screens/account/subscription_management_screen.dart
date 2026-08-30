import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design/kincircle_screen_tokens.dart';
import '../../services/theme_controller.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  String _currentPlan = 'Coordination (Free)';
  bool _processing = false;

  Future<void> _changePlan(String plan) async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      _processing = false;
    });
    await context.read<ThemeController>().setPro(plan == 'Sage Pro');
    if (!mounted) return;
    final palette = KinCirclePalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Switched to $plan plan'),
        backgroundColor: plan == 'Sage Pro' ? palette.success : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with current plan status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _currentPlan == 'Sage Pro'
                      ? [Colors.amber.shade600, Colors.orange.shade700]
                      : [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _currentPlan == 'Sage Pro'
                            ? Icons.workspace_premium
                            : Icons.person,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Current Plan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPlan,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentPlan == 'Sage Pro'
                        ? 'Full premium protection is active.'
                        : 'Choose the tier that fits your family.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Compare Plans',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildPlanCard(
              context,
              title: 'Coordination (Free)',
              subtitle: 'Essential family coordination',
              monthlyPrice: '\$0',
              annualPrice: '\$0',
              features: [
                'Up to 3 circle members',
                '2 saved places',
                '2-day location history',
              ],
              isSelected: _currentPlan == 'Coordination (Free)',
              onTap: () => _changePlan('Coordination (Free)'),
            ),
            const SizedBox(height: 16),

            _buildPlanCard(
              context,
              title: 'Peace of Mind (Plus)',
              subtitle: 'Expanded safety coverage',
              monthlyPrice: '\$9.99/mo',
              annualPrice: '\$89.99/yr',
              features: [
                'Up to 6 members',
                '5 places',
                '30-day history',
                'Crash detection alerts',
              ],
              isSelected: _currentPlan == 'Peace of Mind (Plus)',
              onTap: () => _changePlan('Peace of Mind (Plus)'),
            ),
            const SizedBox(height: 16),

            _buildPlanCard(
              context,
              title: 'Sage Pro',
              subtitle: 'Highest protection and intelligence',
              monthlyPrice: '\$14.99/mo',
              annualPrice: '\$149.99/yr',
              features: [
                'Unlimited members & places',
                'AI Sage insights',
                'Anomaly alerts',
                'Sensory modes',
              ],
              isSelected: _currentPlan == 'Sage Pro',
              isPro: true,
              onTap: () => _changePlan('Sage Pro'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _processing ? null : () {},
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                ),
                child: _processing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long),
                          SizedBox(width: 8),
                          Text(
                            'Choose a plan above to continue',
                            style:
                                TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            if (_currentPlan != 'Sage Pro')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KinCirclePalette.of(context).success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KinCirclePalette.of(context).success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: KinCirclePalette.of(context).success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '30-day money-back guarantee. Cancel anytime.',
                        style: TextStyle(color: KinCirclePalette.of(context).success, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            Text(
              'Frequently Asked Questions',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFAQItem('Can I switch plans anytime?', 
                'Yes! You can upgrade or downgrade at any time. Changes take effect immediately.'),
            _buildFAQItem('What happens to my data if I downgrade?', 
                'Your data is never deleted. Some premium features will be disabled, but you can re-enable them by upgrading again.'),
            _buildFAQItem('Is there a family discount?', 
                'One Pro subscription covers your entire family circle - no per-user fees!'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String monthlyPrice,
    required String annualPrice,
    required List<String> features,
    required bool isSelected,
    bool isPro = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? (isPro ? Colors.amber : scheme.primary)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isPro 
              ? Colors.amber.withValues(alpha: 0.05) 
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPro) ...[
                  Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPro ? Colors.amber.shade700 : null,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPro ? Colors.amber : scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          monthlyPrice,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPro ? Colors.amber.shade700 : scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Annual',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          annualPrice,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPro ? Colors.amber.shade700 : scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ...features.map((String feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(feature)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
      tilePadding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(answer, style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}
