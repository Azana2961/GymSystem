import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

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

class _MemberDetailState extends State<MemberDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysUntilExpiry = widget.member.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysUntilExpiry < 0;

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(widget.member.name[0], style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.member.name, style: Theme.of(context).textTheme.headlineMedium),
                      Text('ID: ${widget.member.id}', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => MemberFormDialog(provider: widget.provider, memberToEdit: widget.member),
                    );
                  },
                  icon: const Icon(Icons.edit, color: AppColors.textSecondary),
                  tooltip: 'Edit Member',
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCountdownBadge(daysUntilExpiry, isExpired),
                Chip(
                  label: Text(widget.member.plan, style: const TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
                  backgroundColor: AppColors.primaryVariant,
                  side: BorderSide.none,
                )
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            dividerColor: AppColors.border,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Attendance'),
              Tab(text: 'Payments'),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                const Center(child: Text('Attendance Data (Placeholder)', style: TextStyle(color: AppColors.textSecondary))),
                const Center(child: Text('Payment History (Placeholder)', style: TextStyle(color: AppColors.textSecondary))),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                widget.provider.updateMember(widget.member.copyWith(
                  expiryDate: isExpired 
                      ? DateTime.now().add(const Duration(days: 30))
                      : widget.member.expiryDate.add(const Duration(days: 30)),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Renew Membership', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBadge(int days, bool isExpired) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error),
        ),
        child: const Text('Expired', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
      );
    }
    
    final isSoon = days <= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSoon ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSoon ? AppColors.warning : AppColors.success),
      ),
      child: Text(
        '$days days left',
        style: TextStyle(
          color: isSoon ? AppColors.warning : AppColors.success,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone, 'Phone', widget.member.phone ?? 'N/A'),
          _buildInfoRow(Icons.email, 'Email', widget.member.email ?? 'N/A'),
          
          const Divider(height: 48, color: AppColors.border),
          
          const Text('Fitness Stats (Dummy)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Weight', '75 kg'),
              _buildStat('Height', '180 cm'),
              _buildStat('BMI', '23.1'),
            ],
          ),
          
          const Divider(height: 48, color: AppColors.border),
          
          const Text('Membership Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoTextRow('Start Date', widget.member.startDate != null 
              ? '${widget.member.startDate!.year}-${widget.member.startDate!.month}-${widget.member.startDate!.day}' 
              : 'N/A'),
          _buildInfoTextRow('Expiry Date', '${widget.member.expiryDate.year}-${widget.member.expiryDate.month}-${widget.member.expiryDate.day}'),
          _buildInfoTextRow(
            'Payment Status', 
            widget.member.isPaymentPending ? 'Pending' : 'Paid', 
            color: widget.member.isPaymentPending ? AppColors.error : AppColors.success
          ),
          
          if (widget.member.notes != null && widget.member.notes!.isNotEmpty) ...[
            const Divider(height: 48, color: AppColors.border),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(widget.member.notes!, style: const TextStyle(color: AppColors.textSecondary)),
          ]
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _buildInfoTextRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}
