import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class MembersFilterBar extends StatelessWidget {
  final MembersProvider provider;

  const MembersFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Plan:', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        _buildDropdown<MemberPlanFilter>(
          value: provider.planFilter,
          items: const [
            DropdownMenuItem(value: MemberPlanFilter.all, child: Text('All Plans')),
            DropdownMenuItem(value: MemberPlanFilter.basic, child: Text('Basic Plan')),
            DropdownMenuItem(value: MemberPlanFilter.silver, child: Text('Silver Plan')),
            DropdownMenuItem(value: MemberPlanFilter.gold, child: Text('Gold Plan')),
            DropdownMenuItem(value: MemberPlanFilter.platinum, child: Text('Platinum Plan')),
          ],
          onChanged: (val) {
            if (val != null) provider.setPlanFilter(val);
          },
        ),
        const Spacer(),
        const Text('Sort by:', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        _buildDropdown<MemberSortOption>(
          value: provider.sortOption,
          items: const [
            DropdownMenuItem(value: MemberSortOption.name, child: Text('Name')),
            DropdownMenuItem(value: MemberSortOption.expiryDate, child: Text('Expiry Date')),
            DropdownMenuItem(value: MemberSortOption.id, child: Text('ID')),
          ],
          onChanged: (val) {
            if (val != null) provider.setSortOption(val);
          },
        ),
        IconButton(
          icon: Icon(
            provider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () {
            provider.setSortOption(provider.sortOption); // Toggles ascending/descending
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppColors.surface,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
