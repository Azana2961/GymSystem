import 'package:flutter/material.dart';
import 'widgets/revenue_chart.dart';
import 'package:gym_system/core/theme/colors.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics & Reports', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 2,
                  child: RevenueChart(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: Card(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grid_on, size: 48, color: AppColors.primary),
                                const SizedBox(height: 16),
                                Text('Peak Hours Heatmap\n(Placeholder)', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Card(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pie_chart, size: 48, color: AppColors.warning),
                                const SizedBox(height: 16),
                                Text('Plan Distribution\n(Placeholder)', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
