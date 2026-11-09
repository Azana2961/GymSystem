import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class MonthlyAnalyticsReport {
  final String monthKey;
  final String monthLabel;
  final double totalRevenue;
  final double baseMembershipRevenue;
  final double joiningAndPtRevenue;
  final String revenueTrend;
  final bool isRevenueUp;
  final int activeMembers;
  final int newSignups;
  final int expiredCount;
  final double pendingDues;
  final int overdueCount;
  final int dailyFootfall;
  final int totalCheckins;
  final Map<String, double> paymentMethods; // Method -> Percentage (0 - 100)
  final Map<String, int> planMembers; // Plan name -> count
  final List<DefaulterRecord> defaulters;
  final List<String> historyMonths; // Dynamic weeks of current month: Week 1, Week 2, ...
  final List<double> historyBaseRevenue;
  final List<double> historyPtRevenue;
  final List<double> historySignups;
  final List<double> historyExpirations;

  const MonthlyAnalyticsReport({
    required this.monthKey,
    required this.monthLabel,
    required this.totalRevenue,
    required this.baseMembershipRevenue,
    required this.joiningAndPtRevenue,
    required this.revenueTrend,
    required this.isRevenueUp,
    required this.activeMembers,
    required this.newSignups,
    required this.expiredCount,
    required this.pendingDues,
    required this.overdueCount,
    required this.dailyFootfall,
    required this.totalCheckins,
    required this.paymentMethods,
    required this.planMembers,
    required this.defaulters,
    required this.historyMonths,
    required this.historyBaseRevenue,
    required this.historyPtRevenue,
    required this.historySignups,
    required this.historyExpirations,
  });
}

class DefaulterRecord {
  final String id;
  final String name;
  final String plan;
  final String phone;
  final double amountDue;
  final int daysOverdue;

  const DefaulterRecord({
    required this.id,
    required this.name,
    required this.plan,
    required this.phone,
    required this.amountDue,
    required this.daysOverdue,
  });
}

class AnalyticsRepository {
  static const List<String> _fullMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Only the current active month (no historical multi-month comparisons)
  static List<String> get availableMonths {
    final now = DateTime.now();
    return ['${_fullMonthNames[now.month - 1]} ${now.year}'];
  }

  static (double, double) _splitMemberRevenue(MemberModel m) {
    if (m.paidAmount <= 0 || m.isVisitor) return (0.0, 0.0);
    final settings = AppSettings.instance;
    final planPrice = settings.getPlanPrice(m.plan);
    if (settings.enableJoiningFee && settings.joiningFeeAmount > 0 && m.paidAmount > planPrice && planPrice > 0) {
      final joining = (m.paidAmount - planPrice).clamp(0.0, settings.joiningFeeAmount);
      final base = (m.paidAmount - joining).clamp(0.0, m.paidAmount);
      return (base, joining);
    }
    return (m.paidAmount, 0.0);
  }

  static MonthlyAnalyticsReport getReport(
    String monthLabel, {
    List<MemberModel>? liveMembers,
    List<Map<String, dynamic>>? attendanceFeed,
    int? todayCheckins,
  }) {
    final now = DateTime.now();
    final allMembers = liveMembers ?? MembersProvider.instance.allMembers;
    final feed = attendanceFeed ?? const [];
    final targetYear = now.year;
    final targetMonth = now.month;
    final currentMonthTitle = '${_fullMonthNames[targetMonth - 1]} $targetYear';

    // Members registered/active in the current month
    final List<MemberModel> periodMembers = allMembers.where((m) {
      final dt = (m.startDate ?? now).toLocal();
      return dt.year == targetYear && dt.month == targetMonth;
    }).toList();

    // Revenue calculation for this month from live SQLite records
    double totalRev = 0.0;
    double baseRev = 0.0;
    double joiningRev = 0.0;

    for (final m in periodMembers) {
      if (m.paidAmount <= 0 || m.isVisitor) continue;
      final (b, j) = _splitMemberRevenue(m);
      totalRev += m.paidAmount;
      baseRev += b;
      joiningRev += j;
    }

    // Active, expired & due counts (100% consistent with Dashboard and Members screen)
    int activeCount = 0;
    int expiredCount = 0;
    double pendingDues = 0.0;
    final List<DefaulterRecord> defaulters = [];

    for (final m in allMembers) {
      final isExp = m.expiryDate.isBefore(now);
      final hasDue = !m.isVisitor && (m.dueAmount > 0 || m.isPaymentPending);
      if (!m.isVisitor && isExp) {
        expiredCount++;
      } else if (!isExp && !hasDue && m.isActive) {
        activeCount++;
      }
      if (hasDue) {
        final dueAmt = m.dueAmount > 0
            ? m.dueAmount
            : AppSettings.instance.getPlanPrice(m.plan);
        pendingDues += dueAmt;
        final overdueDays = isExp ? now.difference(m.expiryDate).inDays.clamp(1, 365) : 0;
        defaulters.add(
          DefaulterRecord(
            id: m.id,
            name: m.name,
            plan: m.plan,
            phone: m.phone ?? 'N/A',
            amountDue: dueAmt,
            daysOverdue: overdueDays,
          ),
        );
      }
    }
    defaulters.sort((a, b) => b.amountDue.compareTo(a.amountDue));

    // Check-ins for this month (includes regular members + visitor scans + visitor registrations)
    int periodCheckins = 0;
    final Set<String> activeCheckinDays = {};
    final Set<String> scannedVisitorIds = {};

    for (final item in feed) {
      final rawTs = item['scanned_at'] ?? item['scan_time'] ?? item['timestamp'] ?? item['created_at'] ?? '';
      final dt = DateTime.tryParse(rawTs.toString().replaceFirst(' ', 'T'))?.toLocal();
      if (dt == null) continue;
      if (dt.year == targetYear && dt.month == targetMonth) {
        periodCheckins++;
        activeCheckinDays.add('${dt.year}-${dt.month}-${dt.day}');
        final mId = item['member_id']?.toString();
        if (mId != null && mId.isNotEmpty) {
          scannedVisitorIds.add(mId);
        }
      }
    }

    // Also count Visitor Pass registrations in this month if not already scanned at the kiosk
    for (final m in periodMembers) {
      if (m.isVisitor && !scannedVisitorIds.contains(m.id)) {
        final dt = (m.startDate ?? now).toLocal();
        periodCheckins++;
        activeCheckinDays.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }

    if (todayCheckins != null && todayCheckins > periodCheckins) {
      periodCheckins = todayCheckins;
    }

    final int dailyFootfall = periodCheckins == 0
        ? 0
        : (activeCheckinDays.isNotEmpty
            ? (periodCheckins / activeCheckinDays.length).round()
            : periodCheckins);

    // Payment method share (%) from real member payment notes
    final configuredMethods = AppSettings.instance.paymentMethods.isNotEmpty
        ? AppSettings.instance.paymentMethods
        : ['Cash', 'Bank Transfer', 'JazzCash', 'Easypaisa'];
    final Map<String, double> methodTotals = {
      for (final method in configuredMethods) method: 0.0,
    };

    for (final m in periodMembers) {
      if (m.paidAmount <= 0 || m.isVisitor) continue;
      final notesLower = (m.notes ?? '').toLowerCase();
      String? matchedMethod;
      for (final method in configuredMethods) {
        if (notesLower.contains(method.toLowerCase())) {
          matchedMethod = method;
          break;
        }
      }
      matchedMethod ??= configuredMethods.first;
      methodTotals[matchedMethod] = (methodTotals[matchedMethod] ?? 0.0) + m.paidAmount;
    }

    final Map<String, double> paymentMethodPct = {};
    for (final entry in methodTotals.entries) {
      paymentMethodPct[entry.key] = totalRev > 0 ? ((entry.value / totalRev) * 100.0) : 0.0;
    }

    // Plan distribution from real members
    final Map<String, int> planMembers = {
      for (final p in AppSettings.instance.plans) p.name: 0,
    };
    for (final m in allMembers) {
      if (m.isVisitor) continue;
      planMembers[m.plan] = (planMembers[m.plan] ?? 0) + 1;
    }

    // Dynamic Weekly Breakdown for ONLY This Month (Week 1 .. Week 4/5)
    final int daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final int weekBuckets = daysInMonth > 28 ? 5 : 4;
    final List<String> historyWeeks = [];
    final List<double> historyBase = List.filled(weekBuckets, 0.0);
    final List<double> historyPt = List.filled(weekBuckets, 0.0);
    final List<double> historySignups = List.filled(weekBuckets, 0.0);
    final List<double> historyExpirations = List.filled(weekBuckets, 0.0);

    for (int w = 0; w < weekBuckets; w++) {
      final startDay = (w * 7) + 1;
      final endDay = ((w + 1) * 7).clamp(startDay, daysInMonth);
      historyWeeks.add('Week ${w + 1} ($startDay–$endDay)');
    }

    for (final m in periodMembers) {
      final dt = (m.startDate ?? now).toLocal();
      final int wIdx = ((dt.day - 1) ~/ 7).clamp(0, weekBuckets - 1);
      if (!m.isVisitor) {
        historySignups[wIdx] += 1;
      }
      if (m.paidAmount > 0 && !m.isVisitor) {
        final (b, j) = _splitMemberRevenue(m);
        historyBase[wIdx] += b;
        historyPt[wIdx] += j;
      }
    }

    for (final m in allMembers) {
      if (m.isVisitor) continue;
      final exp = m.expiryDate.toLocal();
      if (exp.year == targetYear && exp.month == targetMonth && exp.isBefore(now)) {
        final int wIdx = ((exp.day - 1) ~/ 7).clamp(0, weekBuckets - 1);
        historyExpirations[wIdx] += 1;
      }
    }

    final int paidAccountsCount = periodMembers.where((m) => !m.isVisitor && m.paidAmount > 0).length;
    final String trendStr = paidAccountsCount > 0 ? '$paidAccountsCount Paid' : '0 Paid';

    return MonthlyAnalyticsReport(
      monthKey: currentMonthTitle.toLowerCase().replaceAll(' ', '_'),
      monthLabel: currentMonthTitle,
      totalRevenue: totalRev,
      baseMembershipRevenue: baseRev,
      joiningAndPtRevenue: joiningRev,
      revenueTrend: trendStr,
      isRevenueUp: totalRev >= 0,
      activeMembers: activeCount,
      newSignups: periodMembers.where((m) => !m.isVisitor).length,
      expiredCount: expiredCount,
      pendingDues: pendingDues,
      overdueCount: defaulters.length,
      dailyFootfall: dailyFootfall,
      totalCheckins: periodCheckins,
      paymentMethods: paymentMethodPct,
      planMembers: planMembers,
      defaulters: defaulters,
      historyMonths: historyWeeks,
      historyBaseRevenue: historyBase,
      historyPtRevenue: historyPt,
      historySignups: historySignups,
      historyExpirations: historyExpirations,
    );
  }
}
