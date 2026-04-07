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
      SnackBar(
        content: Text('🎉 Switched to $plan plan'),
        backgroundColor: plan == 'Pro' ? Colors.green : null,
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
                  colors: _currentPlan == 'Pro'
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
                        _currentPlan == 'Pro' ? Icons.workspace_premium : Icons.person,
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
                    _currentPlan == 'Pro' ? 'KinCircle Pro' : 'KinCircle Free',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentPlan == 'Pro' 
                        ? 'Enjoy all premium features!' 
                        : 'Upgrade for advanced features',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Billing toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Monthly',
                      style: TextStyle(
                        fontWeight: !_annual ? FontWeight.bold : FontWeight.normal,
                        color: !_annual ? scheme.primary : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _annual,
                    onChanged: (v) => setState(() => _annual = v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Annual',
                      style: TextStyle(
                        fontWeight: _annual ? FontWeight.bold : FontWeight.normal,
                        color: _annual ? scheme.primary : null,
                      ),
                    ),
                  ),
                  if (_annual) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Save 17%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Plan comparison
            Text(
              'Compare Plans',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Free Plan Card
            _buildPlanCard(
              context,
              title: 'Free',
              subtitle: 'Essential family safety',
              price: '\$0',
              period: 'forever',
              features: [
                ('Live location sharing', true),
                ('2 place alerts', true),
                ('Basic check-ins', true),
                ('Unlimited geofences', false),
                ('AI Smart Alerts', false),
                ('Wellbeing Analytics', false),
                ('Priority support', false),
              ],
              isSelected: _currentPlan == 'Free',
              onTap: () => _changePlan('Free'),
            ),
            const SizedBox(height: 16),
            
            // Pro Plan Card
            _buildPlanCard(
              context,
              title: 'Pro',
              subtitle: 'Complete peace of mind',
              price: _annual ? '\$59.99' : '\$5.99',
              period: _annual ? 'year' : 'month',
              features: [
                ('Live location sharing', true),
                ('Unlimited place alerts', true),
                ('Advanced check-ins', true),
                ('Unlimited geofences', true),
                ('AI Smart Alerts', true),
                ('Wellbeing Analytics', true),
                ('Priority support', true),
              ],
              isSelected: _currentPlan == 'Pro',
              isPro: true,
              onTap: () => _changePlan('Pro'),
            ),
            const SizedBox(height: 24),
            
            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _processing 
                    ? null 
                    : () => _changePlan(_currentPlan == 'Pro' ? 'Free' : 'Pro'),
                style: FilledButton.styleFrom(
                  backgroundColor: _currentPlan == 'Pro' ? Colors.grey : scheme.primary,
                ),
                child: _processing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_currentPlan == 'Pro' ? Icons.arrow_downward : Icons.rocket_launch),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentPlan == 'Pro' ? 'Downgrade to Free' : 'Upgrade to Pro',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Money-back guarantee
            if (_currentPlan != 'Pro')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '30-day money-back guarantee. Cancel anytime.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            
            // FAQ Section
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
    required String price,
    required String period,
    required List<(String, bool)> features,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    price,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPro ? Colors.amber.shade700 : scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('/$period', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    f.$2 ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: f.$2 ? Colors.green : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$1,
                      style: TextStyle(
                        color: f.$2 ? null : Colors.grey.shade400,
                        decoration: f.$2 ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
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
