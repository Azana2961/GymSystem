import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';

class TrainerDetailPanel extends StatelessWidget {
  final TrainerModel trainer;
  final List<MemberModel> members;
  final VoidCallback onClose;

  const TrainerDetailPanel({
    super.key,
    required this.trainer,
    required this.members,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
          tooltip: 'Back to Trainers',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trainer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            _StatusBadge(liveStatus: trainer.liveStatus),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Trainer Profile (Coming Soon)'), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            label: const Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
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
                  _buildCenterColumn(),
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
                // Center Column (40%)
                Expanded(flex: 4, child: _buildCenterColumn()),
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
        // Trainer Bio & Photo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundImage: NetworkImage(trainer.avatarUrl),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 16),
                Text(trainer.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(trainer.specialty, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.phone, 'Phone', trainer.phone),
                _buildInfoRow(Icons.badge, 'CNIC/ID', trainer.cnic),
                _buildInfoRow(Icons.emergency, 'Emergency Contact', trainer.emergencyContact),
                _buildInfoRow(Icons.calendar_month, 'Joining Date', trainer.joinDate.toString().substring(0, 10)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Shift Details
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shift & Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.schedule, 'Assigned Hours', '${trainer.shiftStart} – ${trainer.shiftEnd}'),
                _buildInfoRow(Icons.weekend, 'Rest Day', 'Sunday'),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biometric Punch', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Enrolled', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Re-map Fingerprint'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Assigned Clients Roster
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Assigned Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Assign Client'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No clients assigned.', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final m = members[index];
                      // Mock sessions data
                      final totalSessions = 12;
                      final completedSessions = (index * 3) % 12;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text(m.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(m.plan),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$completedSessions / $totalSessions Sessions', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('Exp: ${m.expiryDate.toString().substring(0, 10)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
    final ptCommission = (members.length * 4000); // Mock 4000 PKR per client
    final totalPayout = trainer.baseSalary + ptCommission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Attendance Log
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Mock Heatmap
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(30, (index) {
                    final isActive = index % 7 != 0; // Sundays off
                    final isLate = index % 5 == 0 && isActive;
                    Color color = AppColors.border.withValues(alpha: 0.3);
                    if (isActive) {
                      color = isLate ? AppColors.warning : AppColors.success;
                    }
                    return Tooltip(
                      message: isActive ? (isLate ? 'Late Clock-in' : 'On Time') : 'Rest Day',
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('26 days worked', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Row(
                      children: [
                        Container(width: 10, height: 10, color: AppColors.success),
                        const SizedBox(width: 4),
                        const Text('On Time', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 8),
                        Container(width: 10, height: 10, color: AppColors.warning),
                        const SizedBox(width: 4),
                        const Text('Late', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Salary & Commission Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Salary & Commission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPayoutRow('Base Monthly Salary', 'PKR ${trainer.baseSalary.toInt()}'),
                const SizedBox(height: 8),
                _buildPayoutRow('PT Commission (${(trainer.commissionRate * 100).toInt()}%)', 'PKR $ptCommission'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('PKR $totalPayout', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.payments),
                    label: const Text('Mark Payout Paid'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print),
                    label: const Text('Print Salary Slip'),
                  ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(value, style: const TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String liveStatus;
  const _StatusBadge({required this.liveStatus});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (liveStatus.toLowerCase().contains('free')) {
      color = AppColors.success;
    } else if (liveStatus.toLowerCase().contains('session')) {
      color = AppColors.warning;
    } else {
      color = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(liveStatus,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}