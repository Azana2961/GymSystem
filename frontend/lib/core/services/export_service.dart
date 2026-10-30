import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/features/analytics/models/analytics_data.dart';
import 'package:gym_system/features/members/models/member_model.dart';

class ExportResult {
  final bool success;
  final String filePath;
  final String fileName;
  final String message;

  const ExportResult({
    required this.success,
    required this.filePath,
    required this.fileName,
    required this.message,
  });
}

class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  /// Resolves the user's Downloads or Documents directory on Windows/macOS/Linux/Android
  Future<Directory> _getTargetDirectory() async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    try {
      dir ??= await getApplicationDocumentsDirectory();
    } catch (_) {}
    return dir ?? Directory.current;
  }

  /// Automatically launches the exported file in the default OS application (Excel, Acrobat, etc.)
  Future<void> openExportedFile(String filePath) async {
    try {
      final res = await OpenFilex.open(filePath);
      if (res.type != ResultType.done && Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      }
    } catch (_) {
      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '', filePath]);
        } catch (_) {}
      }
    }
  }

  /// Reveals the exported file in Windows Explorer or file manager
  Future<void> revealInFolder(String filePath) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. ANALYTICS CSV (EXCEL) EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportAnalyticsCsv({
    required MonthlyAnalyticsReport report,
    required double effectiveRevenue,
    required List<DefaulterRecord> udhaarList,
    required double totalUdhaar,
  }) async {
    try {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final safeMonth = report.monthLabel.replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
      final fileName = 'LaFitness_Revenue_Report_${safeMonth}_$dateSlug.csv';

      final dir = await _getTargetDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');

      final buf = StringBuffer();

      // UTF-8 BOM so Microsoft Excel correctly displays rupee symbols and formatting
      buf.write('\uFEFF');

      // Title & Generation Metadata
      buf.writeln('"LÁ FITNESS GYM - MONTHLY REVENUE & OPERATIONAL REPORT"');
      buf.writeln('"Report Month:","${report.monthLabel}"');
      buf.writeln('"Generated On:","${now.toLocal()}"');
      buf.writeln('"Club:","Lá Fitness Club Management"');
      buf.writeln('');

      // Section 1: Executive KPI Metrics
      buf.writeln('"EXECUTIVE KPI SUMMARY"');
      buf.writeln('"Metric","Value","Benchmark / Details"');
      buf.writeln('"Total Monthly Revenue","Rs. ${AppSettings.formatAmount(effectiveRevenue)}","${report.revenueTrend} vs prior quarters"');
      buf.writeln('"Base Memberships Revenue","Rs. ${AppSettings.formatAmount(report.baseMembershipRevenue)}","Core subscription fees"');
      buf.writeln('"Joining & PT Revenue","Rs. ${AppSettings.formatAmount(report.joiningAndPtRevenue)}","New admissions and personal training"');
      buf.writeln('"Active Members Count","${report.activeMembers} Members","+${report.newSignups} new enrollments"');
      buf.writeln('"Pending Dues (Udhaar)","Rs. ${AppSettings.formatAmount(totalUdhaar)}","${udhaarList.length} outstanding accounts"');
      buf.writeln('"Average Daily Footfall","${report.dailyFootfall} Visitors/day","${AppSettings.formatAmount(report.totalCheckins)} check-ins total"');
      buf.writeln('');

      // Section 2: Revenue By Payment Channels
      buf.writeln('"REVENUE RECONCILIATION BY PAYMENT CHANNEL"');
      buf.writeln('"Payment Channel","Share (%)","Estimated Collected (Rs.)"');
      for (final entry in report.paymentMethods.entries) {
        final amount = effectiveRevenue * (entry.value / 100.0);
        buf.writeln('"${entry.key}","${entry.value.toStringAsFixed(1)}%","Rs. ${AppSettings.formatAmount(amount)}"');
      }
      buf.writeln('');

      // Section 3: Membership Tiers Distribution
      buf.writeln('"ACTIVE MEMBERSHIP TIERS BREAKDOWN"');
      buf.writeln('"Membership Tier","Active Member Count","Share of Roster"');
      final totalPlanMembers = report.planMembers.values.fold<int>(0, (s, c) => s + c);
      for (final entry in report.planMembers.entries) {
        final pct = totalPlanMembers > 0 ? ((entry.value / totalPlanMembers) * 100).toStringAsFixed(1) : '0.0';
        buf.writeln('"${entry.key}","${entry.value} Members","$pct%"');
      }
      buf.writeln('');

      // Section 4: Outstanding Dues (Udhaar) Roster
      buf.writeln('"OUTSTANDING DUES (UDHAAR) ACTIONABLE LIST"');
      buf.writeln('"Member ID","Full Name","Phone Number","Plan Tier","Overdue Days","Pending Udhaar (Rs.)"');
      if (udhaarList.isEmpty) {
        buf.writeln('"No pending dues","All member accounts are fully settled","--","--","0","Rs. 0"');
      } else {
        for (final d in udhaarList) {
          final overdueStr = d.daysOverdue > 0 ? '${d.daysOverdue} days' : 'Current';
          buf.writeln('"${d.id}","${d.name}","${d.phone}","${d.plan}","$overdueStr","Rs. ${AppSettings.formatAmount(d.amountDue)}"');
        }
      }
      buf.writeln('');

      // Section 5: Monthly Revenue Growth Benchmark
      buf.writeln('"HISTORICAL REVENUE GROWTH (LAST QUARTERS)"');
      buf.writeln('"Month","Base Revenue (Rs.)","PT & Joining (Rs.)","Total Revenue (Rs.)"');
      for (int i = 0; i < report.historyMonths.length; i++) {
        final mName = report.historyMonths[i];
        final bRev = i < report.historyBaseRevenue.length ? report.historyBaseRevenue[i] : 0.0;
        final pRev = i < report.historyPtRevenue.length ? report.historyPtRevenue[i] : 0.0;
        final tot = bRev + pRev;
        buf.writeln('"$mName","Rs. ${AppSettings.formatAmount(bRev)}","Rs. ${AppSettings.formatAmount(pRev)}","Rs. ${AppSettings.formatAmount(tot)}"');
      }

      await file.writeAsString(buf.toString());
      await openExportedFile(file.path);

      return ExportResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        message: 'CSV Spreadsheet successfully saved to Downloads and opened!',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        fileName: '',
        message: 'Failed to export CSV: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. ANALYTICS PDF SUMMARY REPORT EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportAnalyticsPdf({
    required MonthlyAnalyticsReport report,
    required double effectiveRevenue,
    required List<DefaulterRecord> udhaarList,
    required double totalUdhaar,
  }) async {
    try {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final safeMonth = report.monthLabel.replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
      final fileName = 'LaFitness_Revenue_Report_${safeMonth}_$dateSlug.pdf';

      final dir = await _getTargetDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');

      final pdf = pw.Document(
        title: 'Lá Fitness Revenue Report - ${report.monthLabel}',
        author: 'Lá Fitness Club Management',
      );

      // Colors matching Lá Fitness Theme
      const primaryGold = PdfColor.fromInt(0xFFD4AF37);
      const darkBg = PdfColor.fromInt(0xFF141418);
      const lightBg = PdfColor.fromInt(0xFFF8F9FA);
      const borderGray = PdfColor.fromInt(0xFFE2E8F0);
      const textDark = PdfColor.fromInt(0xFF0F172A);
      const textMuted = PdfColor.fromInt(0xFF64748B);
      const warningOrange = PdfColor.fromInt(0xFFD97706);
      const successGreen = PdfColor.fromInt(0xFF16A34A);

      // Try loading gym logo for PDF header
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/la_fitness_logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          header: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: primaryGold, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 36,
                          height: 36,
                          margin: const pw.EdgeInsets.only(right: 10),
                          child: pw.ClipOval(child: pw.Image(logoImage)),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LÁ FITNESS',
                            style: pw.TextStyle(
                              color: primaryGold,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.Text(
                            'MONTHLY EXECUTIVE PERFORMANCE & REVENUE AUDIT',
                            style: const pw.TextStyle(
                              color: textMuted,
                              fontSize: 8,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: primaryGold,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          report.monthLabel.toUpperCase(),
                          style: pw.TextStyle(
                            color: darkBg,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Generated: ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                        style: const pw.TextStyle(color: textMuted, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 14),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderGray, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Lá Fitness Gym Operating Report • Confidential',
                    style: const pw.TextStyle(color: textMuted, fontSize: 8),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(color: textMuted, fontSize: 8),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) {
            return [
              pw.SizedBox(height: 12),

              // 4 Executive KPI Metric Cards
              pw.Row(
                children: [
                  _buildPdfKpiBox(
                    title: 'MONTHLY REVENUE',
                    value: 'Rs. ${AppSettings.formatAmount(effectiveRevenue)}',
                    subtitle: '${report.revenueTrend} vs last months',
                    borderColor: successGreen,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfKpiBox(
                    title: 'ACTIVE ROSTER',
                    value: '${report.activeMembers} Members',
                    subtitle: '+${report.newSignups} new enrollments',
                    borderColor: primaryGold,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfKpiBox(
                    title: 'PENDING UDHAAR',
                    value: 'Rs. ${AppSettings.formatAmount(totalUdhaar)}',
                    subtitle: '${udhaarList.length} actionable accounts',
                    borderColor: warningOrange,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfKpiBox(
                    title: 'DAILY FOOTFALL',
                    value: '${report.dailyFootfall} Scans/day',
                    subtitle: '${AppSettings.formatAmount(report.totalCheckins)} check-ins total',
                    borderColor: textMuted,
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // Section: Revenue Streams & Payment Methods Breakdown
              pw.Text(
                'REVENUE STREAMS & PAYMENT CHANNELS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.8),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textDark),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                headers: ['Payment Channel', 'Distribution Share (%)', 'Collected Revenue (Rs.)'],
                data: report.paymentMethods.entries.map((e) {
                  final amount = effectiveRevenue * (e.value / 100.0);
                  return [
                    e.key,
                    '${e.value.toStringAsFixed(1)}%',
                    'Rs. ${AppSettings.formatAmount(amount)}',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 18),

              // Section: Outstanding Dues (Udhaar) Defaulters
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'OUTSTANDING DUES (UDHAAR) ACTIONABLE LIST',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  pw.Text(
                    'Total Pending: Rs. ${AppSettings.formatAmount(totalUdhaar)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: warningOrange,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              if (udhaarList.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    border: pw.Border.all(color: borderGray),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Zero Pending Udhaar! All membership accounts are fully paid.',
                      style: pw.TextStyle(fontSize: 9, color: successGreen, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGray, width: 0.8),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textDark),
                  headerDecoration: const pw.BoxDecoration(color: lightBg),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  headers: ['ID', 'Member Name', 'Phone', 'Plan', 'Overdue Status', 'Pending Udhaar'],
                  data: udhaarList.take(20).map((d) {
                    final status = d.daysOverdue > 0 ? '${d.daysOverdue} days overdue' : 'Due this month';
                    return [
                      d.id,
                      d.name,
                      d.phone,
                      d.plan,
                      status,
                      'Rs. ${AppSettings.formatAmount(d.amountDue)}',
                    ];
                  }).toList(),
                ),

              pw.SizedBox(height: 18),

              // Section: Historical Revenue Growth Benchmark
              pw.Text(
                'HISTORICAL REVENUE TRAJECTORY (BENCHMARK)',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.8),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: textDark),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                headers: ['Month', 'Base Memberships', 'PT & Joining Fees', 'Total Monthly Net'],
                data: List.generate(report.historyMonths.length, (i) {
                  final m = report.historyMonths[i];
                  final base = i < report.historyBaseRevenue.length ? report.historyBaseRevenue[i] : 0.0;
                  final pt = i < report.historyPtRevenue.length ? report.historyPtRevenue[i] : 0.0;
                  final tot = base + pt;
                  final isCurrent = i == report.historyMonths.length - 1;
                  return [
                    isCurrent ? '$m (Current)' : m,
                    'Rs. ${AppSettings.formatAmount(base)}',
                    'Rs. ${AppSettings.formatAmount(pt)}',
                    'Rs. ${AppSettings.formatAmount(tot)}',
                  ];
                }),
              ),

              pw.SizedBox(height: 24),

              // Official Signatures / Endorsement Strip
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 1, color: textMuted),
                      pw.SizedBox(height: 4),
                      pw.Text('Prepared By (Front Desk/Accountant)', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 1, color: textMuted),
                      pw.SizedBox(height: 4),
                      pw.Text('Approved By (Managing Director)', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      await openExportedFile(file.path);

      return ExportResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        message: 'PDF Report successfully generated and opened!',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        fileName: '',
        message: 'Failed to export PDF: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. MEMBERS ROSTER CSV EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportMembersCsv(List<MemberModel> members) async {
    try {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'LaFitness_Members_Roster_$dateSlug.csv';

      final dir = await _getTargetDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');

      final buf = StringBuffer();
      buf.write('\uFEFF'); // UTF-8 BOM

      buf.writeln('"LÁ FITNESS GYM - MEMBERS ROSTER EXPORT"');
      buf.writeln('"Exported On:","${now.toLocal()}"');
      buf.writeln('"Total Roster Count:","${members.length}"');
      buf.writeln('');

      buf.writeln('"Member ID","Full Name","Phone","Email","Plan Tier","Status","Pending Udhaar (Rs.)","Paid Amount (Rs.)","Valid From","Expiry Date","Pass Key","Pass Type"');

      for (final m in members) {
        final isExp = m.expiryDate.isBefore(now);
        final hasUdhaar = m.dueAmount > 0 || m.isPaymentPending;
        final status = m.isVisitor
            ? 'Visitor'
            : (isExp ? 'Expired' : (hasUdhaar ? 'Due' : (m.isActive ? 'Active' : 'Inactive')));
        final startDateStr = m.startDate != null ? '${m.startDate!.year}-${m.startDate!.month}-${m.startDate!.day}' : '--';
        final expiryDateStr = '${m.expiryDate.year}-${m.expiryDate.month}-${m.expiryDate.day}';

        buf.writeln(
          '"${m.id}","${m.name}","${m.phone ?? ''}","${m.email ?? ''}","${m.plan}","$status","${m.dueAmount.toInt()}","${m.paidAmount.toInt()}","$startDateStr","$expiryDateStr","${m.qrToken ?? m.id}","${m.isVisitor ? 'Visitor Pass' : 'Standard Member'}"',
        );
      }

      await file.writeAsString(buf.toString());
      await openExportedFile(file.path);

      return ExportResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        message: 'Member roster CSV successfully saved to Downloads and opened!',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        fileName: '',
        message: 'Failed to export members CSV: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. MEMBERS ROSTER PDF EXPORT
  // ──────────────────────────────────────────────────────────────────────────
  Future<ExportResult> exportMembersPdf(List<MemberModel> members) async {
    try {
      final now = DateTime.now();
      final dateSlug = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'LaFitness_Members_Roster_$dateSlug.pdf';

      final dir = await _getTargetDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');

      final pdf = pw.Document(
        title: 'Lá Fitness Members Roster',
        author: 'Lá Fitness Club Management',
      );

      const primaryGold = PdfColor.fromInt(0xFFD4AF37);
      const lightBg = PdfColor.fromInt(0xFFF8F9FA);
      const borderGray = PdfColor.fromInt(0xFFE2E8F0);
      const textDark = PdfColor.fromInt(0xFF0F172A);
      const textMuted = PdfColor.fromInt(0xFF64748B);

      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/la_fitness_logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          header: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: primaryGold, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 32,
                          height: 32,
                          margin: const pw.EdgeInsets.only(right: 8),
                          child: pw.ClipOval(child: pw.Image(logoImage)),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LÁ FITNESS',
                            style: pw.TextStyle(
                              color: primaryGold,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.Text(
                            'OFFICIAL MEMBERS ROSTER DIRECTORY',
                            style: const pw.TextStyle(color: textMuted, fontSize: 8, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Text(
                    'Total Members: ${members.length} • As of ${now.day}/${now.month}/${now.year}',
                    style: const pw.TextStyle(color: textMuted, fontSize: 8.5),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Lá Fitness Gym Member Registry', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(color: textMuted, fontSize: 8)),
                ],
              ),
            );
          },
          build: (pw.Context ctx) {
            return [
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: textDark),
                headerDecoration: const pw.BoxDecoration(color: lightBg),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                headers: ['ID', 'Name', 'Phone', 'Plan', 'Status', 'Udhaar Due', 'Expiry Date'],
                data: members.map((m) {
                  final isExp = m.expiryDate.isBefore(now);
                  final hasUdhaar = m.dueAmount > 0 || m.isPaymentPending;
                  final status = m.isVisitor
                      ? 'Visitor'
                      : (isExp ? 'Expired' : (hasUdhaar ? 'Due' : (m.isActive ? 'Active' : 'Inactive')));
                  final expStr = '${m.expiryDate.year}-${m.expiryDate.month.toString().padLeft(2, '0')}-${m.expiryDate.day.toString().padLeft(2, '0')}';
                  final dueStr = m.dueAmount > 0 ? 'Rs. ${m.dueAmount.toInt()}' : 'Paid';

                  return [
                    m.id,
                    m.name,
                    m.phone ?? '--',
                    m.plan,
                    status,
                    dueStr,
                    expStr,
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      await openExportedFile(file.path);

      return ExportResult(
        success: true,
        filePath: file.path,
        fileName: fileName,
        message: 'Member roster PDF generated and opened!',
      );
    } catch (e) {
      return ExportResult(
        success: false,
        filePath: '',
        fileName: '',
        message: 'Failed to export members PDF: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private Widget Helpers for PDF
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPdfKpiBox({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor borderColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8F9FA),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: borderColor, width: 1.2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(color: PdfColor.fromInt(0xFF64748B), fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(color: const PdfColor.fromInt(0xFF0F172A), fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(color: PdfColor.fromInt(0xFF64748B), fontSize: 6.5),
            ),
          ],
        ),
      ),
    );
  }
}
