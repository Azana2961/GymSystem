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
  final List<String> historyMonths;
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
  static const List<String> availableMonths = [
    'October 2026',
    'September 2026',
    'August 2026',
    'July 2026',
    'June 2026',
    'May 2026',
    'Year-To-Date (2026)',
  ];

  static MonthlyAnalyticsReport getReport(String month) {
    switch (month) {
      case 'September 2026':
        return const MonthlyAnalyticsReport(
          monthKey: 'sep_2026',
          monthLabel: 'September 2026',
          totalRevenue: 430000,
          baseMembershipRevenue: 340000,
          joiningAndPtRevenue: 90000,
          revenueTrend: '+8.9%',
          isRevenueUp: true,
          activeMembers: 230,
          newSignups: 28,
          expiredCount: 14,
          pendingDues: 45000,
          overdueCount: 8,
          dailyFootfall: 248,
          totalCheckins: 7440,
          paymentMethods: {
            'Cash': 58,
            'Credit/Debit Card': 20,
            'Bank Transfer': 12,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 88,
            'Silver Plan': 66,
            'Gold Plan': 48,
            'Platinum Plan': 28,
          },
          defaulters: [
            DefaulterRecord(id: 'M002', name: 'Ayesha Khan', plan: 'Silver Plan', phone: '+92 321 4589211', amountDue: 18000, daysOverdue: 22),
            DefaulterRecord(id: 'M005', name: 'Usman Khalid', plan: 'Basic Plan', phone: '+92 301 7748123', amountDue: 8000, daysOverdue: 19),
            DefaulterRecord(id: 'M007', name: 'Bilal Ahmed', plan: 'Basic Plan', phone: '+92 333 4819201', amountDue: 8000, daysOverdue: 14),
            DefaulterRecord(id: 'M009', name: 'Hamza Tariq', plan: 'Gold Plan', phone: '+92 345 5612890', amountDue: 11000, daysOverdue: 8),
          ],
          historyMonths: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
          historyBaseRevenue: [240000, 260000, 280000, 300000, 320000, 340000],
          historyPtRevenue: [50000, 55000, 60000, 65000, 75000, 90000],
          historySignups: [20, 23, 26, 25, 29, 28],
          historyExpirations: [12, 14, 15, 11, 16, 14],
        );

      case 'August 2026':
        return const MonthlyAnalyticsReport(
          monthKey: 'aug_2026',
          monthLabel: 'August 2026',
          totalRevenue: 395000,
          baseMembershipRevenue: 320000,
          joiningAndPtRevenue: 75000,
          revenueTrend: '+7.4%',
          isRevenueUp: true,
          activeMembers: 216,
          newSignups: 29,
          expiredCount: 16,
          pendingDues: 52000,
          overdueCount: 9,
          dailyFootfall: 236,
          totalCheckins: 7080,
          paymentMethods: {
            'Cash': 60,
            'Credit/Debit Card': 20,
            'Bank Transfer': 10,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 82,
            'Silver Plan': 62,
            'Gold Plan': 46,
            'Platinum Plan': 26,
          },
          defaulters: [
            DefaulterRecord(id: 'M005', name: 'Usman Khalid', plan: 'Basic Plan', phone: '+92 301 7748123', amountDue: 8000, daysOverdue: 35),
            DefaulterRecord(id: 'M007', name: 'Bilal Ahmed', plan: 'Basic Plan', phone: '+92 333 4819201', amountDue: 8000, daysOverdue: 28),
            DefaulterRecord(id: 'M011', name: 'Zeeshan Malik', plan: 'Silver Plan', phone: '+92 300 9812456', amountDue: 18000, daysOverdue: 15),
            DefaulterRecord(id: 'M013', name: 'Talha Sheikh', plan: 'Gold Plan', phone: '+92 322 7712390', amountDue: 18000, daysOverdue: 11),
          ],
          historyMonths: ['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'],
          historyBaseRevenue: [220000, 240000, 260000, 280000, 300000, 320000],
          historyPtRevenue: [45000, 50000, 55000, 60000, 65000, 75000],
          historySignups: [18, 20, 23, 26, 25, 29],
          historyExpirations: [10, 12, 14, 15, 11, 16],
        );

      case 'July 2026':
        return const MonthlyAnalyticsReport(
          monthKey: 'jul_2026',
          monthLabel: 'July 2026',
          totalRevenue: 365000,
          baseMembershipRevenue: 300000,
          joiningAndPtRevenue: 65000,
          revenueTrend: '+6.1%',
          isRevenueUp: true,
          activeMembers: 203,
          newSignups: 25,
          expiredCount: 11,
          pendingDues: 41000,
          overdueCount: 7,
          dailyFootfall: 225,
          totalCheckins: 6750,
          paymentMethods: {
            'Cash': 62,
            'Credit/Debit Card': 18,
            'Bank Transfer': 10,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 78,
            'Silver Plan': 58,
            'Gold Plan': 44,
            'Platinum Plan': 23,
          },
          defaulters: [
            DefaulterRecord(id: 'M007', name: 'Bilal Ahmed', plan: 'Basic Plan', phone: '+92 333 4819201', amountDue: 8000, daysOverdue: 18),
            DefaulterRecord(id: 'M011', name: 'Zeeshan Malik', plan: 'Silver Plan', phone: '+92 300 9812456', amountDue: 18000, daysOverdue: 12),
            DefaulterRecord(id: 'M014', name: 'Fahad Mustafa', plan: 'Basic Plan', phone: '+92 344 6612984', amountDue: 15000, daysOverdue: 9),
          ],
          historyMonths: ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
          historyBaseRevenue: [205000, 220000, 240000, 260000, 280000, 300000],
          historyPtRevenue: [40000, 45000, 50000, 55000, 60000, 65000],
          historySignups: [16, 18, 20, 23, 26, 25],
          historyExpirations: [9, 10, 12, 14, 15, 11],
        );

      case 'June 2026':
        return const MonthlyAnalyticsReport(
          monthKey: 'jun_2026',
          monthLabel: 'June 2026',
          totalRevenue: 340000,
          baseMembershipRevenue: 280000,
          joiningAndPtRevenue: 60000,
          revenueTrend: '+7.7%',
          isRevenueUp: true,
          activeMembers: 195,
          newSignups: 26,
          expiredCount: 15,
          pendingDues: 48000,
          overdueCount: 8,
          dailyFootfall: 212,
          totalCheckins: 6360,
          paymentMethods: {
            'Cash': 64,
            'Credit/Debit Card': 16,
            'Bank Transfer': 10,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 75,
            'Silver Plan': 55,
            'Gold Plan': 42,
            'Platinum Plan': 23,
          },
          defaulters: [
            DefaulterRecord(id: 'M011', name: 'Zeeshan Malik', plan: 'Silver Plan', phone: '+92 300 9812456', amountDue: 18000, daysOverdue: 22),
            DefaulterRecord(id: 'M014', name: 'Fahad Mustafa', plan: 'Basic Plan', phone: '+92 344 6612984', amountDue: 15000, daysOverdue: 17),
            DefaulterRecord(id: 'M016', name: 'Haris Rauf', plan: 'Basic Plan', phone: '+92 312 8841920', amountDue: 15000, daysOverdue: 12),
          ],
          historyMonths: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          historyBaseRevenue: [190000, 205000, 220000, 240000, 260000, 280000],
          historyPtRevenue: [35000, 40000, 45000, 50000, 55000, 60000],
          historySignups: [15, 16, 18, 20, 23, 26],
          historyExpirations: [8, 9, 10, 12, 14, 15],
        );

      case 'May 2026':
        return const MonthlyAnalyticsReport(
          monthKey: 'may_2026',
          monthLabel: 'May 2026',
          totalRevenue: 315000,
          baseMembershipRevenue: 260000,
          joiningAndPtRevenue: 55000,
          revenueTrend: '+8.3%',
          isRevenueUp: true,
          activeMembers: 184,
          newSignups: 23,
          expiredCount: 14,
          pendingDues: 44000,
          overdueCount: 7,
          dailyFootfall: 201,
          totalCheckins: 6030,
          paymentMethods: {
            'Cash': 65,
            'Credit/Debit Card': 15,
            'Bank Transfer': 10,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 72,
            'Silver Plan': 52,
            'Gold Plan': 39,
            'Platinum Plan': 21,
          },
          defaulters: [
            DefaulterRecord(id: 'M014', name: 'Fahad Mustafa', plan: 'Basic Plan', phone: '+92 344 6612984', amountDue: 15000, daysOverdue: 25),
            DefaulterRecord(id: 'M016', name: 'Haris Rauf', plan: 'Basic Plan', phone: '+92 312 8841920', amountDue: 15000, daysOverdue: 19),
            DefaulterRecord(id: 'M018', name: 'Saad Farooq', plan: 'Silver Plan', phone: '+92 333 1129847', amountDue: 14000, daysOverdue: 14),
          ],
          historyMonths: ['Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'],
          historyBaseRevenue: [175000, 190000, 205000, 220000, 240000, 260000],
          historyPtRevenue: [30000, 35000, 40000, 45000, 50000, 55000],
          historySignups: [14, 15, 16, 18, 20, 23],
          historyExpirations: [7, 8, 9, 10, 12, 14],
        );

      case 'Year-To-Date (2026)':
        return const MonthlyAnalyticsReport(
          monthKey: 'ytd_2026',
          monthLabel: 'Year-To-Date (2026)',
          totalRevenue: 2323000,
          baseMembershipRevenue: 1840000,
          joiningAndPtRevenue: 483000,
          revenueTrend: '+24.5%',
          isRevenueUp: true,
          activeMembers: 248,
          newSignups: 159,
          expiredCount: 86,
          pendingDues: 38000,
          overdueCount: 6,
          dailyFootfall: 231,
          totalCheckins: 41580,
          paymentMethods: {
            'Cash': 57,
            'Credit/Debit Card': 21,
            'Bank Transfer': 12,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 95,
            'Silver Plan': 72,
            'Gold Plan': 53,
            'Platinum Plan': 28,
          },
          defaulters: [
            DefaulterRecord(id: 'M002', name: 'Ayesha Khan', plan: 'Silver Plan', phone: '+92 321 4589211', amountDue: 18000, daysOverdue: 5),
            DefaulterRecord(id: 'M005', name: 'Usman Khalid', plan: 'Basic Plan', phone: '+92 301 7748123', amountDue: 8000, daysOverdue: 2),
            DefaulterRecord(id: 'M007', name: 'Bilal Ahmed', plan: 'Basic Plan', phone: '+92 333 4819201', amountDue: 5000, daysOverdue: 7),
            DefaulterRecord(id: 'M009', name: 'Hamza Tariq', plan: 'Gold Plan', phone: '+92 345 5612890', amountDue: 7000, daysOverdue: 4),
          ],
          historyMonths: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
          historyBaseRevenue: [260000, 280000, 300000, 320000, 340000, 385000],
          historyPtRevenue: [55000, 60000, 65000, 75000, 90000, 100000],
          historySignups: [23, 26, 25, 29, 28, 34],
          historyExpirations: [14, 15, 11, 16, 14, 16],
        );

      case 'October 2026':
      default:
        return const MonthlyAnalyticsReport(
          monthKey: 'oct_2026',
          monthLabel: 'October 2026',
          totalRevenue: 485000,
          baseMembershipRevenue: 385000,
          joiningAndPtRevenue: 100000,
          revenueTrend: '+12.8%',
          isRevenueUp: true,
          activeMembers: 248,
          newSignups: 34,
          expiredCount: 16,
          pendingDues: 38000,
          overdueCount: 6,
          dailyFootfall: 264,
          totalCheckins: 7920,
          paymentMethods: {
            'Cash': 56,
            'Credit/Debit Card': 22,
            'Bank Transfer': 12,
            'JazzCash/Easypaisa': 10,
          },
          planMembers: {
            'Basic Plan': 95,
            'Silver Plan': 72,
            'Gold Plan': 53,
            'Platinum Plan': 28,
          },
          defaulters: [
            DefaulterRecord(id: 'M002', name: 'Ayesha Khan', plan: 'Silver Plan', phone: '+92 321 4589211', amountDue: 18000, daysOverdue: 5),
            DefaulterRecord(id: 'M005', name: 'Usman Khalid', plan: 'Basic Plan', phone: '+92 301 7748123', amountDue: 8000, daysOverdue: 2),
            DefaulterRecord(id: 'M007', name: 'Bilal Ahmed', plan: 'Basic Plan', phone: '+92 333 4819201', amountDue: 5000, daysOverdue: 7),
            DefaulterRecord(id: 'M009', name: 'Hamza Tariq', plan: 'Gold Plan', phone: '+92 345 5612890', amountDue: 7000, daysOverdue: 4),
          ],
          historyMonths: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
          historyBaseRevenue: [260000, 280000, 300000, 320000, 340000, 385000],
          historyPtRevenue: [55000, 60000, 65000, 75000, 90000, 100000],
          historySignups: [23, 26, 25, 29, 28, 34],
          historyExpirations: [14, 15, 11, 16, 14, 16],
        );
    }
  }
}
