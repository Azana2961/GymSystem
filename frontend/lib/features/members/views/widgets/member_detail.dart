import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/widgets/receipt_qr_dialog.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/features/dashboard/views/widgets/collect_payment_dialog.dart';
import 'package:gym_system/core/services/api_service.dart';

class MemberDetail extends StatefulWidget {
  final MemberModel member;
  final MembersProvider provider;
  final VoidCallback onClose;

  const MemberDetail({
    super.key,
    required this.member,
    required this.provider,
    required this.onClose,
  });

  @override
  State<MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<MemberDetail> {
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoadingAttendance = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoadingAttendance = true);
    try {
      final records = await ApiService.instance.getMemberAttendance(widget.member.id);
      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _isLoadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAttendance = false);
      }
    }
  }

  void _saveNewNote() {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final existing = widget.member.notes?.trim() ?? '';
    final timestamp = DateTime.now().toString().substring(0, 16);
    final combined = existing.isEmpty ? '[$timestamp] $text' : '$existing\n[$timestamp] $text';

    final updated = widget.member.copyWith(notes: combined);
    widget.provider.updateMember(updated);
    _noteController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved successfully!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final daysUntilExpiry = member.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysUntilExpiry < 0;

    String status = 'Active';
    Color statusColor = AppColors.success;
    if (member.isPaymentPending || isExpired) {
      status = 'Overdue / Expired';
      statusColor = AppColors.error;
    } else if (daysUntilExpiry <= 5) {
      status = 'Expiring Soon';
      statusColor = AppColors.warning;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
          tooltip: 'Back to Members',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => MemberFormDialog(provider: widget.provider, memberToEdit: member),
              );
            },
            icon: const Icon(Icons.edit, color: AppColors.textPrimary, size: 18),
            label: const Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ReceiptQrDialog(
                  member: member,
                  planFee: AppSettings.instance.getPlanPrice(member.plan),
                  admissionFee: 0.0,
                  discount: 0.0,
                  totalPaid: member.paidAmount > 0 ? member.paidAmount : AppSettings.instance.getPlanPrice(member.plan),
                  paymentMethod: 'Active',
                  isNewRegistration: false,
                ),
              );
            },
            icon: const Icon(Icons.badge_rounded, size: 16, color: AppColors.primary),
            label: const Text('Member Pass', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CollectPaymentDialog(initialMember: member),
                );
              },
              icon: const Icon(Icons.payments_rounded, color: Colors.black, size: 18),
              label: const Text('Collect Fee / Renew', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Close',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 950;
            if (!isWide) {
              return Column(
                children: [
                  _buildLeftColumn(context, statusColor),
                  const SizedBox(height: 24),
                  _buildMiddleColumn(context),
                  const SizedBox(height: 24),
                  _buildRightColumn(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLeftColumn(context, statusColor)),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: _buildMiddleColumn(context)),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: _buildRightColumn()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, Color statusColor) {
    final member = widget.member;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Monogram & Verified Member Details
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.14),
                    border: Border.all(color: statusColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(member.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'ID: ${member.id} • ${member.qrToken ?? member.id}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Strictly Fields Mentioned in Add Member
                _buildInfoRow(Icons.phone_rounded, 'Phone Number', member.phone?.isNotEmpty == true ? member.phone! : 'N/A'),
                _buildInfoRow(Icons.email_rounded, 'Email Address', member.email?.isNotEmpty == true ? member.email! : 'N/A'),
                _buildInfoRow(Icons.person_outline_rounded, 'Gender', member.gender?.isNotEmpty == true ? member.gender! : 'Not Specified'),
                _buildInfoRow(Icons.card_membership_rounded, 'Membership Plan', member.plan),
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  'Registration Date',
                  member.startDate != null ? member.startDate!.toString().substring(0, 10) : 'N/A',
                ),
                _buildInfoRow(
                  Icons.event_available_rounded,
                  'Expiry Date',
                  member.expiryDate.toString().substring(0, 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Digital Access Pass Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Digital Access Pass', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 12),
                          SizedBox(width: 4),
                          Text('ACTIVE', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.qrToken ?? member.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          const Text('Ready for kiosk check-in scan', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ReceiptQrDialog(
                            member: member,
                            planFee: AppSettings.instance.getPlanPrice(member.plan),
                            admissionFee: 0.0,
                            discount: 0.0,
                            totalPaid: member.paidAmount > 0 ? member.paidAmount : AppSettings.instance.getPlanPrice(member.plan),
                            paymentMethod: 'Active',
                            isNewRegistration: false,
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_rounded, size: 14, color: Colors.black),
                      label: const Text('View Pass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleColumn(BuildContext context) {
    final member = widget.member;
    final daysUntilExpiry = member.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysUntilExpiry < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current Plan Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Membership Plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.plan,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start Date: ${member.startDate?.toString().substring(0, 10) ?? 'N/A'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Expiry Date: ${member.expiryDate.toString().substring(0, 10)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? AppColors.error.withValues(alpha: 0.1)
                            : (daysUntilExpiry <= 5
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : AppColors.success.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isExpired
                              ? AppColors.error
                              : (daysUntilExpiry <= 5 ? AppColors.warning : AppColors.success),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isExpired ? 'Expired' : '$daysUntilExpiry',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isExpired
                                  ? AppColors.error
                                  : (daysUntilExpiry <= 5 ? AppColors.warning : AppColors.success),
                            ),
                          ),
                          if (!isExpired)
                            Text(
                              'Days Left',
                              style: TextStyle(
                                color: daysUntilExpiry <= 5 ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Real Due / Udhaar Alert
                if (member.dueAmount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pending Udhaar: Rs. ${AppSettings.formatAmount(member.dueAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => CollectPaymentDialog(initialMember: member),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Collect Udhaar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Real Payment & Fee Breakdown Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Billing & Payment Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: member.dueAmount > 0
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member.dueAmount > 0 ? 'UDHAAR PENDING' : 'ACCOUNT CLEAR',
                        style: TextStyle(
                          color: member.dueAmount > 0 ? AppColors.warning : AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Financial Breakdown Rows
                _buildPaymentSummaryRow('Enrolled Plan', member.plan, AppColors.textPrimary),
                const Divider(height: 18),
                _buildPaymentSummaryRow(
                  'Total Paid to Date',
                  'Rs. ${AppSettings.formatAmount(member.paidAmount)}',
                  AppColors.success,
                  isBold: true,
                ),
                const Divider(height: 18),
                _buildPaymentSummaryRow(
                  'Outstanding Due (Udhaar)',
                  'Rs. ${AppSettings.formatAmount(member.dueAmount)}',
                  member.dueAmount > 0 ? AppColors.error : AppColors.textMuted,
                  isBold: member.dueAmount > 0,
                ),
                const SizedBox(height: 18),

                // Action to collect fee or view receipt
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => CollectPaymentDialog(initialMember: member),
                          );
                        },
                        icon: const Icon(Icons.payment_rounded, size: 16),
                        label: const Text('Collect / Renew Fee'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (member.paidAmount > 0) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ReceiptQrDialog(
                              member: member,
                              planFee: AppSettings.instance.getPlanPrice(member.plan),
                              admissionFee: 0.0,
                              discount: 0.0,
                              totalPaid: member.paidAmount,
                              paymentMethod: 'Recorded',
                              isNewRegistration: false,
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.black),
                        label: const Text('View Receipt', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    final member = widget.member;
    final now = DateTime.now();

    final thisMonthScans = _attendanceRecords.where((r) {
      final dt = DateTime.tryParse(r['scanned_at']?.toString() ?? '');
      return dt != null && dt.year == now.year && dt.month == now.month;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Real Attendance History from SQLite
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Attendance History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${thisMonthScans.length} scans this month',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isLoadingAttendance)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else if (_attendanceRecords.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.event_available_rounded, size: 36, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'No attendance scans recorded yet',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attendanceRecords.take(6).length,
                    separatorBuilder: (_, _) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = _attendanceRecords[index];
                      final scannedAt = item['scanned_at']?.toString() ?? '';
                      final dt = DateTime.tryParse(scannedAt);
                      final displayDate = dt != null
                          ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                          : scannedAt;
                      final st = item['status']?.toString().toLowerCase() ?? 'paid';

                      Color badgeColor = AppColors.success;
                      String badgeText = 'VALID SCAN';
                      if (st == 'expired') {
                        badgeColor = AppColors.error;
                        badgeText = 'EXPIRED';
                      } else if (st == 'due') {
                        badgeColor = AppColors.warning;
                        badgeText = 'DUE';
                      } else if (st == 'visitor') {
                        badgeColor = const Color(0xFF00E5FF);
                        badgeText = 'VISITOR';
                      }

                      return Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: badgeColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayDate,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Real Staff Notes from Member Record
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Staff Notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    member.notes?.trim().isNotEmpty == true ? member.notes! : 'No notes recorded for this member.',
                    style: TextStyle(
                      fontSize: 13,
                      color: member.notes?.trim().isNotEmpty == true ? AppColors.textPrimary : AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Note input field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Add a new note...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onSubmitted: (_) => _saveNewNote(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      onPressed: _saveNewNote,
                      tooltip: 'Save Note',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
