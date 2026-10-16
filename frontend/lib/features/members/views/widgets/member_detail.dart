import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class MemberDetail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final daysUntilExpiry = member.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysUntilExpiry < 0;
    
    String status = 'Active';
    Color statusColor = AppColors.success;
    if (member.isPaymentPending || isExpired) {
      status = 'Overdue';
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
          onPressed: onClose,
          tooltip: 'Back to Members',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Chip(
              backgroundColor: statusColor.withValues(alpha: 0.1),
              label: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              side: BorderSide.none,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => MemberFormDialog(provider: provider, memberToEdit: member),
                );
            },
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            label: const Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                provider.updateMember(member.copyWith(
                  expiryDate: isExpired 
                      ? DateTime.now().add(const Duration(days: 30))
                      : member.expiryDate.add(const Duration(days: 30)),
                ));
              },
              icon: const Icon(Icons.autorenew),
              label: const Text('Renew Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            if (!isWide) {
              return Column(
                children: [
                  _buildLeftColumn(),
                  const SizedBox(height: 24),
                  _buildMiddleColumn(),
                  const SizedBox(height: 24),
                  _buildRightColumn(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (30%)
                Expanded(flex: 3, child: _buildLeftColumn()),
                const SizedBox(width: 24),
                // Middle Column (40%)
                Expanded(flex: 4, child: _buildMiddleColumn()),
                const SizedBox(width: 24),
                // Right Column (30%)
                Expanded(flex: 3, child: _buildRightColumn()),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Photo & Core Details
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${member.id}'),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 16),
                Text(member.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('ID: ${member.id}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.phone, 'Phone', member.phone ?? 'N/A'),
                _buildInfoRow(Icons.email, 'Email', member.email ?? 'N/A'),
                _buildInfoRow(Icons.cake, 'Date of Birth', '1990-05-14 (Mock)'),
                _buildInfoRow(Icons.emergency, 'Emergency Contact', '+1 555 9999 (Mock)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hardware Setup Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hardware Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.fingerprint, color: AppColors.success, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fingerprint', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Registered (Thumb)', style: TextStyle(color: AppColors.success, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: (){}, child: const Text('Scan New')),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: AppColors.warning, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('App Pass', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Pending', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: (){}, child: const Text('Generate QR')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleColumn() {
    final daysUntilExpiry = member.expiryDate.difference(DateTime.now()).inDays;
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
                const Text('Current Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.plan, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 8),
                          Text('Start Date: ${member.startDate?.toString().substring(0,10) ?? 'N/A'}', style: const TextStyle(color: AppColors.textSecondary)),
                          Text('Expiry Date: ${member.expiryDate.toString().substring(0,10)}', style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: daysUntilExpiry < 0 ? AppColors.error.withValues(alpha: 0.1) : (daysUntilExpiry <= 7 ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: daysUntilExpiry < 0 ? AppColors.error : (daysUntilExpiry <= 7 ? AppColors.warning : AppColors.success)),
                      ),
                      child: Column(
                        children: [
                          Text(daysUntilExpiry < 0 ? 'Expired' : '$daysUntilExpiry', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: daysUntilExpiry < 0 ? AppColors.error : (daysUntilExpiry <= 7 ? AppColors.warning : AppColors.success))),
                          if (daysUntilExpiry >= 0) Text('Days Left', style: TextStyle(color: daysUntilExpiry <= 7 ? AppColors.warning : AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                if (member.isPaymentPending) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Pending Dues: \$50.00', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                          child: const Text('Collect Fee'),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Payment History
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.success,
                        child: Icon(Icons.attach_money, color: Colors.white),
                      ),
                      title: const Text('Membership Renewal', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Processed by Staff A • Cash'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('\$50.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.receipt_long), onPressed: (){}, tooltip: 'Reprint Receipt'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Attendance Heatmap
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance (Current Month)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Mock Heatmap
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(35, (index) {
                    final isActive = index % 3 == 0 || index % 5 == 0;
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success : AppColors.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('12 check-ins this month', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Staff Notes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Staff Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('12 Oct, 09:41 AM (Staff A)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(member.notes ?? 'No notes available.', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Add a new note...',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    suffixIcon: IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: (){}),
                  ),
                  maxLines: 2,
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(value, style: const TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
