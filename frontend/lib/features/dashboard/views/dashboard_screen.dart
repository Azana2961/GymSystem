import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'widgets/kpi_card.dart';
import 'widgets/live_feed.dart';
import 'widgets/expiry_reminders.dart';
import 'widgets/collect_payment_dialog.dart';
import 'package:gym_system/core/constants/app_settings.dart';
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
    _membersProvider.addListener(_onMembersUpdated);
    _fetchStats();
    _statsPoller = Timer.periodic(const Duration(seconds: 4), (_) => _fetchStats());
  }

  void _onMembersUpdated() {
    if (mounted) {
      setState(() {});
      _fetchStats();
    }
  }

  @override
  void dispose() {
    _membersProvider.removeListener(_onMembersUpdated);
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

  void _openTabletKioskDialog(BuildContext context) async {
    final netInfo = await ApiService.instance.getNetworkInfo();
    final tabletUrl = netInfo?['tabletUrl'] ?? 'http://localhost:5000/tablet';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tablet_mac_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tablet Kiosk Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                SizedBox(height: 2),
                Text('Scan QR or open in tablet browser', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: jsonEncode({
                    'serverUrl': netInfo?['baseUrl'] ?? 'http://localhost:5000',
                    'tabletUrl': tabletUrl,
                    'wsUrl': netInfo?['wsUrl'] ?? 'ws://localhost:5000/ws',
                    'primaryIp': netInfo?['primaryIp'] ?? '127.0.0.1',
                    'gymName': 'Lá Fitness',
                  }),
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  tabletUrl,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open this link on any tablet (iPad / Android / Fire) or scan this QR with the tablet camera to auto-connect. All new members sync live and attendance works offline!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                if (Platform.isWindows) {
                  await Process.run('cmd', ['/c', 'start', tabletUrl]);
                } else if (Platform.isMacOS) {
                  await Process.run('open', [tabletUrl]);
                } else if (Platform.isLinux) {
                  await Process.run('xdg-open', [tabletUrl]);
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: const Text('Open in Browser'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayCheckinsInt = (_liveStats?['todayCheckins'] as num?)?.toInt() ?? 0;
    final yesterdayCheckinsInt = (_liveStats?['yesterdayCheckins'] as num?)?.toInt() ?? 0;
    final checkinDiff = todayCheckinsInt - yesterdayCheckinsInt;
    final checkinTrend = checkinDiff >= 0 ? '+$checkinDiff vs yesterday' : '$checkinDiff vs yesterday';

    final activeInt = (_liveStats?['activeMembers'] as num?)?.toInt() ?? _membersProvider.activeMembersCount;
    final dueInt = (_liveStats?['dueMembers'] as num?)?.toInt() ?? _membersProvider.pendingPaymentCount;
    final expiredInt = (_liveStats?['expiredMembers'] as num?)?.toInt() ?? _membersProvider.expiredMembersCount;
    final totalInt = (_liveStats?['totalMembers'] as num?)?.toInt() ?? _membersProvider.totalMembersCount;
    final visitorInt = (_liveStats?['visitorMembers'] as num?)?.toInt() ??
        _membersProvider.allMembers.where((m) => m.isVisitor).length;
    final regularInt = (totalInt - visitorInt).clamp(0, totalInt);
    final totalDueRs = (_liveStats?['totalDueAmount'] as num?)?.toDouble() ?? _membersProvider.totalDueAmount;
    final activeRate = totalInt > 0 ? ((activeInt / totalInt) * 100).round() : 100;

    final checkins = todayCheckinsInt.toString();
    final active = activeInt.toString();
    final due = (dueInt + expiredInt).toString();
    final total = totalInt.toString();

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
                    const SizedBox(width: 14),

                    OutlinedButton.icon(
                      onPressed: () => _openTabletKioskDialog(context),
                      icon: const Icon(Icons.tablet_mac_rounded, color: AppColors.primary, size: 18),
                      label: const Text(
                        'Tablet Kiosk',
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
                    trend: checkinTrend,
                    isTrendUp: checkinDiff >= 0,
                    trendDescription: 'Yesterday: $yesterdayCheckinsInt check-ins',
                  ),
                  KpiCard(
                    title: 'Active Members',
                    value: active,
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppColors.primary,
                    trend: '$activeRate% Active',
                    isTrendUp: activeRate >= 50,
                    trendDescription: 'Paid & valid memberships',
                  ),
                  KpiCard(
                    title: 'Due / Expiring Soon',
                    value: due,
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    trend: totalDueRs > 0
                        ? 'Rs. ${AppSettings.formatAmount(totalDueRs)} Udhaar'
                        : (dueInt + expiredInt > 0 ? '${dueInt + expiredInt} Actionable' : 'Rs. 0 Udhaar'),
                    isTrendUp: dueInt == 0 && expiredInt == 0 && totalDueRs == 0,
                    trendDescription: '$dueInt Udhaar • $expiredInt expired',
                  ),
                  KpiCard(
                    title: 'Total Roster',
                    value: total,
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.success,
                    trend: '$regularInt Regular',
                    isTrendUp: true,
                    trendDescription: visitorInt > 0 ? '$visitorInt Visitor passes issued' : 'All registered members',
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
