import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/analytics/views/widgets/financial_tab.dart';
import 'package:gym_system/features/analytics/views/widgets/membership_tab.dart';
import 'package:gym_system/features/analytics/views/widgets/operations_tab.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Analytics & Reports', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.file_download),
                      label: const Text('Monthly Excel Export'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('End of Day (EOD) Report'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.border,
              tabs: const [
                Tab(text: 'Financial Health (Revenue & Cash Flow)'),
                Tab(text: 'Membership & Retention (Growth)'),
                Tab(text: 'Operations & Attendance (Efficiency)'),
              ],
            ),
            const SizedBox(height: 24),
            const Expanded(
              child: TabBarView(
                children: [
                  FinancialTab(),
                  MembershipTab(),
                  OperationsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
