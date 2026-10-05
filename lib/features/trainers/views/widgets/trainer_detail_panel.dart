import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/views/widgets/member_detail.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class TrainerDetailPanel extends StatefulWidget {
  final String trainerName;
  final String specialty;
  final bool isClockedIn;
  final String avatarUrl;
  final String shiftTime;
  final List<MemberModel> members;
  final VoidCallback onClose;

  const TrainerDetailPanel({
    super.key,
    required this.trainerName,
    required this.specialty,
    required this.isClockedIn,
    required this.avatarUrl,
    required this.shiftTime,
    required this.members,
    required this.onClose,
  });

  @override
  State<TrainerDetailPanel> createState() => _TrainerDetailPanelState();
}

class _TrainerDetailPanelState extends State<TrainerDetailPanel> {
  final MembersProvider _provider = MembersProvider();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _planFilter = 'All';
  bool _onlyActive = false;

  @override
  void dispose() {
    _provider.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MemberModel> get _filtered {
    final q = _searchQuery.toLowerCase();
    return widget.members.where((m) {
      final matchesSearch = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.id.toLowerCase().contains(q);
      final matchesPlan =
          _planFilter == 'All' || m.plan.toLowerCase().contains(_planFilter.toLowerCase());
      final matchesActive = !_onlyActive || (!m.isExpired && m.isActive && !m.isPaymentPending);
      return matchesSearch && matchesPlan && matchesActive;
    }).toList();
  }

  List<String> get _plans {
    final set = <String>{for (final m in widget.members) m.plan};
    return ['All', ...set];
  }

  int get _activeCount => widget.members
      .where((m) => !m.isExpired && m.isActive && !m.isPaymentPending)
      .length;

  int get _attentionCount =>
      widget.members.where((m) => m.isExpired || m.isPaymentPending).length;

  void _openMember(MemberModel member) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: MemberDetail(
            member: member,
            provider: _provider,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _filtered;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Back to trainers',
                      onPressed: widget.onClose,
                    ),
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.border,
                          backgroundImage: NetworkImage(widget.avatarUrl),
                          onBackgroundImageError: (_, __) {},
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: widget.isClockedIn ? AppColors.success : AppColors.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.trainerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.primary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.group_rounded,
                      value: '${widget.members.length}',
                      label: 'Allocated',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.check_circle_outline,
                      value: '$_activeCount',
                      label: 'Active',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.error_outline,
                      value: '$_attentionCount',
                      label: 'Attention',
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                color: AppColors.textSecondary,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: _inputBorder(),
                        enabledBorder: _inputBorder(),
                        focusedBorder: _inputBorder(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 42,
                  child: FilterChip(
                    label: Text(_onlyActive ? 'Active only' : 'All statuses'),
                    labelStyle: TextStyle(
                      color: _onlyActive ? Colors.black : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary,
                    showCheckmark: false,
                    side: BorderSide(color: _onlyActive ? AppColors.primary : AppColors.border),
                    onSelected: (v) => setState(() => _onlyActive = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final plan in _plans) ...[
                    _PlanChip(
                      label: plan,
                      selected: _planFilter == plan,
                      onTap: () => setState(() => _planFilter = plan),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'Members to Train',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${members.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: members.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      widget.members.isEmpty
                          ? 'No members allocated to this trainer.'
                          : 'No members match your filters.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 700
                              ? 2
                              : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 78,
                        ),
                        itemCount: members.length,
                        itemBuilder: (_, i) => _MemberRow(
                          member: members[i],
                          onTap: () => _openMember(members[i]),
                        ),
                      );
                    },
                  ),
          ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder({Color color = AppColors.border}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      );
}

class _PlanChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PlanChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.18) : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

class _MemberRow extends StatelessWidget {
  final MemberModel member;
  final VoidCallback onTap;

  const _MemberRow({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final expired = member.isExpired;
    final pending = member.isPaymentPending;

    final Color statusColor = expired
        ? AppColors.error
        : pending
            ? AppColors.warning
            : AppColors.success;
    final String statusLabel = expired
        ? 'Expired'
        : pending
            ? 'Payment Due'
            : member.daysUntilExpiry <= 7
                ? 'Expiring Soon'
                : 'Active';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.18),
                child: Text(
                  member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.plan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                        Text(
                          member.id,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}