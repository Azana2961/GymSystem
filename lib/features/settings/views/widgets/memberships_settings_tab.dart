import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class MembershipsSettingsTab extends StatelessWidget {
  const MembershipsSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Membership Plans', style: Theme.of(context).textTheme.titleLarge),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Plan'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              _buildPlanCard(context, 'Basic Plan', '\$29.99', 'Monthly', 'Access to cardio and weight room'),
              const SizedBox(height: 16),
              _buildPlanCard(context, 'Silver Plan', '\$49.99', 'Monthly', 'Basic + Group Classes'),
              const SizedBox(height: 16),
              _buildPlanCard(context, 'Gold Plan', '\$79.99', 'Monthly', 'Silver + Pool & Sauna Access'),
              const SizedBox(height: 16),
              _buildPlanCard(context, 'Platinum Plan', '\$99.99', 'Monthly', 'All Inclusive + 2 PT Sessions'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context, String name, String price, String duration, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Chip(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        label: Text(duration, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(price, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary)),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.secondary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
