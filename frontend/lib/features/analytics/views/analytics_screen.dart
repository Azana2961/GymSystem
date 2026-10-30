import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/analytics/models/analytics_data.dart';
import 'package:gym_system/features/dashboard/views/widgets/collect_payment_dialog.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedMonth = 'October 2026';
  final MembersProvider _membersProvider = MembersProvider.instance;

  MonthlyAnalyticsReport get _report => AnalyticsRepository.getReport(_selectedMonth);

  @override
  void initState() {
    super.initState();
    _membersProvider.addListener(_onDataChanged);
    AppSettings.instance.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _membersProvider.removeListener(_onDataChanged);
    AppSettings.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  /// Combines live members who have Udhaar (`dueAmount > 0` or `isPaymentPending`) with report defaulters
  List<DefaulterRecord> _getCombinedUdhaarList(MonthlyAnalyticsReport report) {
    final Map<String, DefaulterRecord> byId = {};

    // 1. Live members from SQLite / MembersProvider with Udhaar or pending payment
    for (final m in _membersProvider.allMembers) {
      if (m.isVisitor) continue;
      final hasDue = m.dueAmount > 0 || m.isPaymentPending;
      if (hasDue) {
        final amount = m.dueAmount > 0
            ? m.dueAmount
            : AppSettings.instance.getPlanPrice(m.plan);
        final overdueDays = m.expiryDate.isBefore(DateTime.now())
            ? DateTime.now().difference(m.expiryDate).inDays.clamp(1, 365)
            : 0;
        byId[m.id] = DefaulterRecord(
          id: m.id,
          name: m.name,
          phone: m.phone ?? '+92 300 0000000',
          plan: m.plan,
          amountDue: amount,
          daysOverdue: overdueDays,
        );
      }
    }

    // 2. Include historical report defaulters if not already settled in live members
    for (final d in report.defaulters) {
      final liveMatch = _membersProvider.allMembers.where((m) => m.id == d.id).firstOrNull;
      if (liveMatch != null) {
        // If live member exists and has 0 due and is not pending, they already paid their Udhaar!
        if (liveMatch.dueAmount <= 0 && !liveMatch.isPaymentPending) {
          continue;
        }
      }
      byId.putIfAbsent(d.id, () => d);
    }

    final list = byId.values.toList();
    list.sort((a, b) => b.amountDue.compareTo(a.amountDue));
    return list;
  }

  double _getLiveTotalUdhaar(List<DefaulterRecord> udhaarList) {
    return udhaarList.fold<double>(0.0, (sum, item) => sum + item.amountDue);
  }

  void _openCollectDialog(DefaulterRecord defaulter) {
    MemberModel? member;
    try {
      member = _membersProvider.allMembers.firstWhere((m) => m.id == defaulter.id);
    } catch (_) {
      member = MemberModel(
        id: defaulter.id,
        name: defaulter.name,
        plan: defaulter.plan,
        expiryDate: DateTime.now().subtract(Duration(days: defaulter.daysOverdue)),
        isPaymentPending: true,
        dueAmount: defaulter.amountDue,
        phone: defaulter.phone,
        notes: 'Udhaar Rs. ${AppSettings.formatAmount(defaulter.amountDue)}',
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
    final udhaarList = _getCombinedUdhaarList(report);
    final totalUdhaar = _getLiveTotalUdhaar(udhaarList);

    // Add live collected payments from SQLite members on top of historical report for October 2026
    final livePaidBonus = _selectedMonth == 'October 2026'
        ? _membersProvider.allMembers.fold<double>(0.0, (s, m) => s + m.paidAmount)
        : 0.0;
    final effectiveRevenue = report.totalRevenue + livePaidBonus;

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
                          'Analytics & Revenue Hub',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lá Fitness Revenue Performance, Payment Channels & Udhaar Recovery',
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
                    value: 'Rs. ${AppSettings.formatAmount(effectiveRevenue)}',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.primary,
                    trend: report.revenueTrend,
                    isTrendUp: report.isRevenueUp,
                    subtitle:
                        'Base Rs. ${AppSettings.formatAmount(report.baseMembershipRevenue + livePaidBonus)} + PT Rs. ${AppSettings.formatAmount(report.joiningAndPtRevenue)}',
                  ),
                  _buildMetricCard(
                    title: 'Active Members',
                    value: '${report.activeMembers} Members',
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.success,
                    trend: '+${report.newSignups} Sign-ups',
                    isTrendUp: true,
                    subtitle: '${udhaarList.length} Udhaar / due accounts',
                  ),
                  _buildMetricCard(
                    title: 'Pending Dues (Udhaar)',
                    value: 'Rs. ${AppSettings.formatAmount(totalUdhaar)}',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    trend: '${udhaarList.length} Udhaar Accounts',
                    isTrendUp: false,
                    subtitle: 'Actionable pending fee recovery',
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

          // MAIN ROW: ALL ABOUT REVENUE (LEFT) + OUTSTANDING DUES / UDHAAR SECTION (RIGHT)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1050;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildRevenueAnalyticsCard(report, effectiveRevenue, totalUdhaar),
                    const SizedBox(height: 16),
                    _buildDuesRecoveryCard(udhaarList, totalUdhaar),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildRevenueAnalyticsCard(report, effectiveRevenue, totalUdhaar),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _buildDuesRecoveryCard(udhaarList, totalUdhaar),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // BOTTOM ROW: FULL-WIDTH PEAK HOURS & TURNSTILE FLOW HEATMAP
          _buildPeakHoursHeatmapCard(),
        ],
      ),
    );
  }

  // --- COMPREHENSIVE REVENUE ANALYTICS CARD (ALL ABOUT REVENUE, NO PIE CHARTS) ---
  Widget _buildRevenueAnalyticsCard(
    MonthlyAnalyticsReport report,
    double effectiveRevenue,
    double totalUdhaar,
  ) {
    final count = report.historyMonths.length;
    final startIndex = (count >= 5) ? count - 5 : 0;
    final compareMonths = report.historyMonths.sublist(startIndex);
    final compareBase = List<double>.from(report.historyBaseRevenue.sublist(startIndex));
    final comparePt = List<double>.from(report.historyPtRevenue.sublist(startIndex));

    if (compareBase.isNotEmpty) {
      final extra = effectiveRevenue - report.totalRevenue;
      if (extra > 0) {
        compareBase[compareBase.length - 1] += extra;
      }
    }

    double prevTotal = 0;
    if (compareBase.length >= 2) {
      prevTotal = compareBase[compareBase.length - 2] + comparePt[comparePt.length - 2];
    }
    final curTotal = effectiveRevenue;
    final diff = curTotal - prevTotal;
    final growthPct = prevTotal > 0 ? ((diff / prevTotal) * 100).toStringAsFixed(1) : '12.8';

    final paymentEntries = report.paymentMethods.entries.toList();
    final channelColors = [
      const Color(0xFF10B981), // Cash
      const Color(0xFF42A5F5), // Card
      const Color(0xFFFFA726), // Bank Transfer
      AppColors.primary, // JazzCash / Easypaisa
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
                      'Revenue Performance & Channel Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Monthly revenue trajectory, fee stream split, and payment collection channels',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        '+$growthPct% Revenue Growth',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 Revenue KPI Strip Badges
            Row(
              children: [
                _buildGrowthStatBadge(
                  'Collected Revenue',
                  'Rs. ${AppSettings.formatAmount(curTotal)}',
                  AppColors.primary,
                ),
                const SizedBox(width: 10),
                _buildGrowthStatBadge(
                  'Previous Month',
                  'Rs. ${AppSettings.formatAmount(prevTotal)}',
                  AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                _buildGrowthStatBadge(
                  'Net Gain',
                  '${diff >= 0 ? '+' : '-'}Rs. ${AppSettings.formatAmount(diff.abs())}',
                  diff >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 10),
                _buildGrowthStatBadge(
                  'Pending Udhaar',
                  'Rs. ${AppSettings.formatAmount(totalUdhaar)}',
                  AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Bar Chart: Monthly Revenue Trajectory
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 600,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final mName = compareMonths[groupIndex];
                        final isCurrent = groupIndex == compareMonths.length - 1;
                        final total = rod.toY.toInt();
                        return BarTooltipItem(
                          '$mName ${isCurrent ? "(Current)" : ""}\nRs. ${total}k Collected',
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
                        interval: 100,
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
                          toY: (baseK + ptK).clamp(0, 590),
                          width: 34,
                          borderRadius: BorderRadius.circular(6),
                          borderSide: isCurrent
                              ? const BorderSide(color: AppColors.primary, width: 2)
                              : BorderSide.none,
                          rodStackItems: [
                            BarChartRodStackItem(
                              0,
                              baseK,
                              isCurrent ? AppColors.primary : AppColors.primary.withValues(alpha: 0.65),
                            ),
                            BarChartRodStackItem(
                              baseK,
                              baseK + ptK,
                              isCurrent
                                  ? const Color(0xFF42A5F5)
                                  : const Color(0xFF42A5F5).withValues(alpha: 0.65),
                            ),
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
                const SizedBox(width: 20),
                _buildChartLegend('Joining Fee & Personal Training', const Color(0xFF42A5F5)),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: AppColors.border, height: 1),
            ),

            // Horizontal Revenue Breakdown by Payment Method (No Pie Charts)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenue by Payment Method',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  '$_selectedMonth Collection Channels',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: List.generate(paymentEntries.length, (i) {
                final entry = paymentEntries[i];
                final color = channelColors[i % channelColors.length];
                final pct = entry.value;
                final amount = curTotal * (pct / 100.0);
                return Container(
                  width: 225,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${pct.toInt()}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Rs. ${AppSettings.formatAmount(amount)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DUES RECOVERY (UDHAAR) CARD (ON THE RIGHT OF REVENUE) ---
  Widget _buildDuesRecoveryCard(List<DefaulterRecord> udhaarList, double totalUdhaar) {
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
                    Icon(Icons.account_balance_wallet_rounded, color: AppColors.warning, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Outstanding Dues (Udhaar)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'Rs. ${AppSettings.formatAmount(totalUdhaar)} Due',
                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Members with pending Udhaar balances (${udhaarList.length} accounts) — click Collect to settle',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (udhaarList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Zero Pending Udhaar!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All member balances are fully settled.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 410),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: udhaarList.length,
                  separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final d = udhaarList[index];
                    final statusLabel = d.daysOverdue > 0
                        ? '${d.plan} • Overdue ${d.daysOverdue}d'
                        : '${d.plan} • Pending Udhaar';
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                          child: Text(
                            d.name.isNotEmpty ? d.name[0].toUpperCase() : 'M',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      d.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${d.id})',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                statusLabel,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${AppSettings.formatAmount(d.amountDue)}',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _openCollectDialog(d),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Collect',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
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
                    Text(
                      'Peak Hours & Turnstile Flow',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Check-in volume heatmap across weekly operating hours',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Low', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Peak',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
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
                              child: Text(
                                days[dayIdx],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
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
                                message:
                                    '${days[dayIdx]} ${h > 12 ? '${h - 12} PM' : (h == 12 ? '12 PM' : '$h AM')}: ${(intensity * 95).toInt()} Check-ins',
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
