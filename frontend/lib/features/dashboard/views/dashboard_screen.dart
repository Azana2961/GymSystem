import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/kpi_card.dart';
import 'widgets/live_feed.dart';
import 'widgets/expiry_reminders.dart';
import 'widgets/collect_payment_dialog.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/services/api_service.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MembersProvider _membersProvider = MembersProvider.instance;
  Map<String, dynamic>? _liveStats;
  Timer? _statsPoller;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _statsPoller = Timer.periodic(const Duration(seconds: 4), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _statsPoller?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await ApiService.instance.getStats();
      if (mounted && stats != null) {
        setState(() {
          _liveStats = stats;
        });
      }
    } catch (_) {}
  }

  void _openNewRegistration(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => MemberFormDialog(
        provider: _membersProvider,
      ),
    );
  }

  void _openCollectPayment(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CollectPaymentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkins = _liveStats?['todayCheckins']?.toString() ?? '0';
    final active = _liveStats?['activeMembers']?.toString() ?? _membersProvider.activeMembersCount.toString();
    final due = _liveStats?['dueMembers']?.toString() ?? _membersProvider.pendingPaymentCount.toString();
    final total = _liveStats?['totalMembers']?.toString() ?? _membersProvider.totalMembersCount.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Action Bar with Gym Dashboard branding and quick action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title and Status
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
                          'Dashboard Overview',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'SQLite Connected • Live Tablet Feed & WhatsApp Engine Active',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Quick Action Buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openNewRegistration(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 18),
                      label: const Text(
                        'New Registration',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    OutlinedButton.icon(
                      onPressed: () => _openCollectPayment(context),
                      icon: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 18),
                      label: const Text(
                        'Collect Payment',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KPI Cards Grid (Directly from SQLite)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              return GridView.count(
                crossAxisCount: isNarrow ? 2 : 4,
                shrinkWrap: true,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: isNarrow ? 2.0 : 1.65,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  KpiCard(
                    title: "Total Check-ins Today",
                    value: checkins,
                    icon: Icons.login_rounded,
                    iconColor: AppColors.primary,
                    trend: 'LIVE',
                    isTrendUp: true,
                    trendDescription: 'From tablet scans',
                  ),
                  KpiCard(
                    title: 'Active Members',
                    value: active,
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppColors.primary,
                    trend: 'SQLITE',
                    isTrendUp: true,
                    trendDescription: 'Paid & valid passes',
                  ),
                  KpiCard(
                    title: 'Due / Expiring Soon',
                    value: due,
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    trend: 'ALERTS',
                    isTrendUp: false,
                    trendDescription: 'WhatsApp candidates',
                  ),
                  KpiCard(
                    title: 'Total Roster',
                    value: total,
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.success,
                    trend: 'TOTAL',
                    isTrendUp: true,
                    trendDescription: 'Registered members',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Live Attendance & Expiry Reminders Sections
          const Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: LiveFeedWidget(),
                ),
                SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  child: ExpiryRemindersWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
