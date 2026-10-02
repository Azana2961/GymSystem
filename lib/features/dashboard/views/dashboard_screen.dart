import 'package:flutter/material.dart';
import 'widgets/kpi_card.dart';
import 'widgets/live_feed.dart';
import 'package:gym_system/core/theme/colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineLarge),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Check-In'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              return GridView.count(
                crossAxisCount: isNarrow ? 2 : 4,
                shrinkWrap: true,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: isNarrow ? 2.0 : 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  KpiCard(
                    title: "Today's Check-ins",
                    value: '142',
                    icon: Icons.login,
                    iconColor: Colors.blueAccent,
                    trend: '+12%',
                    isTrendUp: true,
                  ),
                  KpiCard(
                    title: 'Active Members',
                    value: '840',
                    icon: Icons.people,
                    iconColor: AppColors.primary,
                    trend: '+5%',
                    isTrendUp: true,
                  ),
                  KpiCard(
                    title: 'Fees Collected',
                    value: '\$12,450',
                    icon: Icons.attach_money,
                    iconColor: AppColors.success,
                    trend: '+18%',
                    isTrendUp: true,
                  ),
                  KpiCard(
                    title: 'Pending Dues',
                    value: '\$3,200',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    trend: '-2%',
                    isTrendUp: false,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: LiveFeedWidget()),
                SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Center(
                      child: Text(
                        'Upcoming Classes Widget\n(Placeholder)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
