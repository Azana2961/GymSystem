import 'package:flutter/material.dart';
import 'widgets/kpi_card.dart';
import 'widgets/live_feed.dart';
import 'widgets/critical_alerts.dart';
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
            ],
          ),
          const SizedBox(height: 16),
          // High-Priority Quick Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: SearchBar(
                    hintText: 'Manual Check-in (Name, ID, Phone)...',
                    leading: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.search),
                    ),
                    elevation: WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(AppColors.background),
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add),
                  label: const Text('New Registration'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.payment),
                  label: const Text('Collect Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
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
                    title: "Total Check-ins Today",
                    value: '142',
                    icon: Icons.login,
                    iconColor: Colors.blueAccent,
                    trend: '+12%',
                    isTrendUp: true,
                    trendDescription: 'vs daily average',
                  ),
                  KpiCard(
                    title: 'New Sign-ups Today',
                    value: '8',
                    icon: Icons.person_add,
                    iconColor: AppColors.primary,
                    trend: '+2',
                    isTrendUp: true,
                    trendDescription: 'vs daily average',
                  ),
                  KpiCard(
                    title: 'Revenue Collected Today',
                    value: '\$1,250',
                    icon: Icons.attach_money,
                    iconColor: AppColors.success,
                    trend: '+5%',
                    isTrendUp: true,
                    trendDescription: 'vs daily average',
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
                  child: CriticalAlertsWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
