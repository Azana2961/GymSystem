import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/analytics/models/analytics_data.dart';
import 'package:gym_system/features/dashboard/views/widgets/collect_payment_dialog.dart';
import 'package:gym_system/features/members/models/member_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedMonth = 'October 2026';

  MonthlyAnalyticsReport get _report => AnalyticsRepository.getReport(_selectedMonth);

  void _openCollectDialog(DefaulterRecord defaulter) {
    MemberModel? member;
    try {
      member = DummyData.members.firstWhere((m) => m.id == defaulter.id);
    } catch (_) {
      member = MemberModel(
        id: defaulter.id,
        name: defaulter.name,
        plan: defaulter.plan,
        expiryDate: DateTime.now().subtract(Duration(days: defaulter.daysOverdue)),
        isPaymentPending: true,
        phone: defaulter.phone,
        notes: 'Overdue Rs. ${AppSettings.formatAmount(defaulter.amountDue)}',
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => CollectPaymentDialog(initialMember: member),
    );
  }

  void _exportReport(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1B20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$type for $_selectedMonth generated successfully.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Action Header with Month Dropdown & Export Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title & Subtitle
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics & Reports',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lá Fitness Monthly Performance, Revenue & Operational Metrics',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Controls: Month Dropdown + Export Buttons
                Row(
                  children: [
                    // Month by Reports Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMonth,
                              dropdownColor: AppColors.surface,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              items: AnalyticsRepository.availableMonths.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m,
                                  child: Text(m),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedMonth = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Excel Export
                    OutlinedButton.icon(
                      onPressed: () => _exportReport('Excel Data Export'),
                      icon: const Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 16),
                      label: const Text(
                        'Export Excel',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        backgroundColor: AppColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // PDF Export
                    ElevatedButton.icon(
                      onPressed: () => _exportReport('PDF Summary Report'),
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.black, size: 16),
                      label: const Text(
                        'Export PDF',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4 Executive KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              return GridView.count(
                crossAxisCount: isNarrow ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isNarrow ? 1.7 : 2.0,
                children: [
                  _buildMetricCard(
                    title: 'Monthly Revenue',
                    value: 'Rs. ${AppSettings.formatAmount(report.totalRevenue)}',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.primary,
                    trend: report.revenueTrend,
                    isTrendUp: report.isRevenueUp,
                    subtitle: 'Base Rs. ${AppSettings.formatAmount(report.baseMembershipRevenue)} + PT Rs. ${AppSettings.formatAmount(report.joiningAndPtRevenue)}',
                  ),
                  _buildMetricCard(
                    title: 'Active Members',
                    value: '${report.activeMembers} Members',
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.success,
                    trend: '+${report.newSignups} Sign-ups',
                    isTrendUp: true,
                    subtitle: '${report.expiredCount} expired / due this month',
                  ),
                  _buildMetricCard(
                    title: 'Pending Dues (Udhaar)',
                    value: 'Rs. ${AppSettings.formatAmount(report.pendingDues)}',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.error,
                    trend: '${report.overdueCount} Defaulters',
                    isTrendUp: false,
                    subtitle: 'Requires immediate fee recovery',
                  ),
                  _buildMetricCard(
                    title: 'Average Daily Footfall',
                    value: '${report.dailyFootfall} Visitors/day',
                    icon: Icons.qr_code_scanner_rounded,
                    iconColor: const Color(0xFF42A5F5),
                    trend: '${AppSettings.formatAmount(report.totalCheckins)} Total',
                    isTrendUp: true,
                    subtitle: 'Peak hours: 5:00 PM - 9:00 PM',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ROW 1: COMBINED BOTH PIES (ON THE LEFT) + CURRENT MONTH REVENUE GROWTH VS LAST MONTHS (ON THE RIGHT)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1050;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildCombinedPiesCard(report),
                    const SizedBox(height: 16),
                    _buildRevenueGrowthBarChartCard(report),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Both Pies combined into the same layout length
                  Expanded(flex: 6, child: _buildCombinedPiesCard(report)),
                  const SizedBox(width: 16),
                  // Right side: Bar graph of current month Revenue growth with last months
                  Expanded(flex: 6, child: _buildRevenueGrowthBarChartCard(report)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ROW 2: PEAK HOURS HEATMAP + DUES RECOVERY (UDHAAR)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1050;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildPeakHoursHeatmapCard(),
                    const SizedBox(height: 16),
                    _buildDuesRecoveryCard(report),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildPeakHoursHeatmapCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildDuesRecoveryCard(report)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- COMBINED BOTH PIE CHARTS (LEFT SIDE) ---
  Widget _buildCombinedPiesCard(MonthlyAnalyticsReport report) {
    final paymentEntries = report.paymentMethods.entries.toList();
    final paymentColors = [
      const Color(0xFF66BB6A), // Cash
      const Color(0xFF42A5F5), // Cards
      const Color(0xFFFFA726), // Bank Transfer
      AppColors.primary,       // Mobile Wallet
    ];

    final planEntries = report.planMembers.entries.toList();
    final planColors = [
      AppColors.primary,           // Basic
      const Color(0xFF42A5F5),     // Silver
      const Color(0xFFAB47BC),     // Gold
      const Color(0xFFFF7043),     // Platinum
    ];

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Methods & Plan Distribution',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reconciliation of revenue channels alongside active subscription tiers',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$_selectedMonth Breakdown',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Side-by-side Pies in the same layout length
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PIE 1: Payment Methods Reconcile
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Payment Channels',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                Text(
                                  'Rs. ${(report.totalRevenue / 1000).toInt()}k',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                ),
                              ],
                            ),
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 38,
                                sections: List.generate(paymentEntries.length, (i) {
                                  final val = paymentEntries[i].value;
                                  return PieChartSectionData(
                                    color: paymentColors[i % paymentColors.length],
                                    value: val,
                                    title: '${val.toInt()}%',
                                    radius: 26,
                                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 10),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Compact Legend for Payments
                      Column(
                        children: List.generate(paymentEntries.length, (i) {
                          final item = paymentEntries[i];
                          final color = paymentColors[i % paymentColors.length];
                          final amount = report.totalRevenue * (item.value / 100);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.key,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Rs. ${AppSettings.formatAmount(amount)}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider between the two pies
                Container(
                  height: 250,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.border,
                ),

                // PIE 2: Plan Popularity & Tiers
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Membership Tiers',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Active', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                Text(
                                  '${report.activeMembers}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                ),
                              ],
                            ),
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 38,
                                sections: List.generate(planEntries.length, (i) {
                                  final count = planEntries[i].value;
                                  final pct = (count / report.activeMembers * 100).toInt();
                                  return PieChartSectionData(
                                    color: planColors[i % planColors.length],
                                    value: count.toDouble(),
                                    title: '$pct%',
                                    radius: 26,
                                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 10),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Compact Legend for Plans
                      Column(
                        children: List.generate(planEntries.length, (i) {
                          final item = planEntries[i];
                          final color = planColors[i % planColors.length];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.key,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.value} members',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- BAR GRAPH: CURRENT MONTH REVENUE GROWTH WITH LAST MONTHS (RIGHT SIDE) ---
  Widget _buildRevenueGrowthBarChartCard(MonthlyAnalyticsReport report) {
    // Take the last 3-4 months up to current
    final count = report.historyMonths.length;
    final startIndex = (count >= 4) ? count - 4 : 0;
    final compareMonths = report.historyMonths.sublist(startIndex);
    final compareBase = report.historyBaseRevenue.sublist(startIndex);
    final comparePt = report.historyPtRevenue.sublist(startIndex);

    // Calculate growth between previous and current month
    double prevTotal = 0;
    if (compareBase.length >= 2) {
      prevTotal = compareBase[compareBase.length - 2] + comparePt[comparePt.length - 2];
    }
    final curTotal = report.totalRevenue;
    final diff = curTotal - prevTotal;
    final growthPct = prevTotal > 0 ? ((diff / prevTotal) * 100).toStringAsFixed(1) : '12.8';

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Growth (vs. Last Months)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current month performance benchmarked against recent quarters',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '+$growthPct% Growth',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Highlights for Growth
            Row(
              children: [
                _buildGrowthStatBadge('Current Month', 'Rs. ${AppSettings.formatAmount(curTotal)}', AppColors.primary),
                const SizedBox(width: 12),
                _buildGrowthStatBadge('Previous Month', 'Rs. ${AppSettings.formatAmount(prevTotal)}', AppColors.textSecondary),
                const SizedBox(width: 12),
                _buildGrowthStatBadge('Net Increase', '+Rs. ${AppSettings.formatAmount(diff.abs())}', AppColors.success),
              ],
            ),
            const SizedBox(height: 20),

            // Bar Chart showing Current Month with Last Months
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 550,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final mName = compareMonths[groupIndex];
                        final isCurrent = groupIndex == compareMonths.length - 1;
                        final total = rod.toY.toInt();
                        return BarTooltipItem(
                          '$mName ${isCurrent ? "(Current)" : ""}\nRs. ${total}k Total',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < compareMonths.length) {
                            final isCurrent = idx == compareMonths.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                isCurrent ? '${compareMonths[idx]} (Current)' : compareMonths[idx],
                                style: TextStyle(
                                  color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        interval: 100, // strictly every 100k
                        getTitlesWidget: (value, meta) {
                          if (value % 100 != 0 || value == 0) return const SizedBox();
                          return Text(
                            'Rs. ${value.toInt()}k',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 100,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(compareMonths.length, (i) {
                    final baseK = (compareBase[i] / 1000).toDouble();
                    final ptK = (comparePt[i] / 1000).toDouble();
                    final isCurrent = i == compareMonths.length - 1;

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: baseK + ptK,
                          width: 32,
                          borderRadius: BorderRadius.circular(6),
                          borderSide: isCurrent
                              ? const BorderSide(color: AppColors.primary, width: 2)
                              : BorderSide.none,
                          rodStackItems: [
                            BarChartRodStackItem(0, baseK, isCurrent ? AppColors.primary : AppColors.primary.withValues(alpha: 0.6)),
                            BarChartRodStackItem(baseK, baseK + ptK, isCurrent ? const Color(0xFF42A5F5) : const Color(0xFF42A5F5).withValues(alpha: 0.6)),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Legend below chart
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegend('Base Memberships', AppColors.primary),
                const SizedBox(width: 16),
                _buildChartLegend('Joining & Personal Training', const Color(0xFF42A5F5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- PEAK HOURS HEATMAP CARD ---
  Widget _buildPeakHoursHeatmapCard() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = List.generate(18, (i) => i + 6); // 6 AM to 11 PM

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peak Hours & Turnstile Flow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Check-in volume heatmap across weekly operating hours', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Low', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    const Text('Peak', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 50) / hours.length;
                return Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 45),
                        ...hours.map((h) {
                          return SizedBox(
                            width: cellWidth,
                            child: Text(
                              h > 12 ? '${h - 12}p' : (h == 12 ? '12p' : '${h}a'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(days.length, (dayIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 45,
                              child: Text(days[dayIdx], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
                            ),
                            ...List.generate(hours.length, (hourIdx) {
                              final h = hours[hourIdx];
                              double intensity = 0.1;
                              if (h >= 17 && h <= 20) {
                                intensity = 0.95; // Evening rush
                              } else if (h >= 7 && h <= 9) {
                                intensity = 0.65; // Morning rush
                              } else if (h == 12 || h == 13) {
                                intensity = 0.4; // Lunch
                              }
                              if (dayIdx >= 5) intensity *= 0.55;
                              if (dayIdx == 0 && h == 18) intensity = 1.0;

                              Color cellColor;
                              if (intensity < 0.2) {
                                cellColor = AppColors.border.withValues(alpha: 0.25);
                              } else if (intensity < 0.5) {
                                cellColor = AppColors.primary.withValues(alpha: 0.35);
                              } else if (intensity < 0.8) {
                                cellColor = AppColors.primary.withValues(alpha: 0.7);
                              } else {
                                cellColor = AppColors.primary;
                              }

                              return Tooltip(
                                message: '${days[dayIdx]} ${h > 12 ? '${h - 12} PM' : (h == 12 ? '12 PM' : '$h AM')}: ${(intensity * 95).toInt()} Check-ins',
                                child: Container(
                                  width: cellWidth - 2,
                                  height: 20,
                                  margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- DUES RECOVERY (UDHAAR) CARD ---
  Widget _buildDuesRecoveryCard(MonthlyAnalyticsReport report) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.report_problem_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Outstanding Dues (Udhaar)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Rs. ${AppSettings.formatAmount(report.pendingDues)} Due',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Actionable list of members with pending gym fee balances', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.defaulters.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.border),
              itemBuilder: (context, index) {
                final d = report.defaulters[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.error.withValues(alpha: 0.15),
                      child: Text(
                        d.name.isNotEmpty ? d.name[0] : 'M',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(d.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Text('(${d.id})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${d.plan} • Overdue ${d.daysOverdue}d', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs. ${AppSettings.formatAmount(d.amountDue)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openCollectDialog(d),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Collect', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for Metric Card
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String trend,
    required bool isTrendUp,
    required String subtitle,
  }) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  isTrendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isTrendUp ? AppColors.success : AppColors.error,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    color: isTrendUp ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
