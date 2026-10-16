import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class SummaryCards extends StatelessWidget {
  final MembersProvider provider;

  const SummaryCards({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow ? constraints.maxWidth / 2 - 8 : constraints.maxWidth / 4 - 12;
        
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildCard(
              title: 'Total Members',
              value: provider.totalMembersCount.toString(),
              icon: Icons.people,
              color: AppColors.primary,
              width: cardWidth,
              isSelected: provider.statusFilter == MemberStatusFilter.all,
              onTap: () => provider.setStatusFilter(MemberStatusFilter.all),
            ),
            _buildCard(
              title: 'Active',
              value: provider.activeMembersCount.toString(),
              icon: Icons.check_circle,
              color: AppColors.success,
              width: cardWidth,
              isSelected: provider.statusFilter == MemberStatusFilter.active,
              onTap: () => provider.setStatusFilter(MemberStatusFilter.active),
            ),
            _buildCard(
              title: 'Inactive',
              value: provider.inactiveMembersCount.toString(),
              icon: Icons.cancel,
              color: AppColors.error,
              width: cardWidth,
              isSelected: provider.statusFilter == MemberStatusFilter.inactive,
              onTap: () => provider.setStatusFilter(MemberStatusFilter.inactive),
            ),
            _buildCard(
              title: 'Expiring Soon',
              value: provider.expiringSoonCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              width: cardWidth,
              isSelected: provider.statusFilter == MemberStatusFilter.expiringSoon,
              onTap: () => provider.setStatusFilter(MemberStatusFilter.expiringSoon),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
