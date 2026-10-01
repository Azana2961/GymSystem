import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({Key? key, required this.selectedIndex, required this.onItemSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: AppColors.primary, size: 32),
                const SizedBox(width: 12),
                Text(
                  'IRON CORE',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _SidebarItem(icon: Icons.dashboard, title: 'Dashboard', index: 0, selectedIndex: selectedIndex, onItemSelected: onItemSelected),
          _SidebarItem(icon: Icons.people, title: 'Members', index: 1, selectedIndex: selectedIndex, onItemSelected: onItemSelected),
          _SidebarItem(icon: Icons.sports_kabaddi, title: 'Trainers', index: 2, selectedIndex: selectedIndex, onItemSelected: onItemSelected),
          _SidebarItem(icon: Icons.bar_chart, title: 'Analytics', index: 3, selectedIndex: selectedIndex, onItemSelected: onItemSelected),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, color: AppColors.textPrimary),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    Text('Logout', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int index;
  final int selectedIndex;
  final Function(int) onItemSelected;

  const _SidebarItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemSelected(index),
        hoverColor: AppColors.primary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected ? const Border(right: BorderSide(color: AppColors.primary, width: 4)) : null,
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.secondary, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
