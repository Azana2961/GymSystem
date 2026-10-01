import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({Key? key, required this.selectedIndex, required this.onItemSelected}) : super(key: key);

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isCollapsed ? 80 : 250,
      color: AppColors.surface,
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 16 : 24),
            child: OverflowBox(
              maxWidth: 250 - (_isCollapsed ? 32 : 48),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.fitness_center, color: AppColors.primary, size: 32),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'IRON CORE',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: _isCollapsed ? Alignment.center : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 16),
              child: IconButton(
                icon: Icon(_isCollapsed ? Icons.chevron_right : Icons.chevron_left, color: AppColors.textSecondary),
                onPressed: () {
                  setState(() {
                    _isCollapsed = !_isCollapsed;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SidebarItem(icon: Icons.dashboard, title: 'Dashboard', index: 0, selectedIndex: widget.selectedIndex, onItemSelected: widget.onItemSelected, isCollapsed: _isCollapsed),
          _SidebarItem(icon: Icons.people, title: 'Members', index: 1, selectedIndex: widget.selectedIndex, onItemSelected: widget.onItemSelected, isCollapsed: _isCollapsed),
          _SidebarItem(icon: Icons.sports_kabaddi, title: 'Trainers', index: 2, selectedIndex: widget.selectedIndex, onItemSelected: widget.onItemSelected, isCollapsed: _isCollapsed),
          _SidebarItem(icon: Icons.bar_chart, title: 'Analytics', index: 3, selectedIndex: widget.selectedIndex, onItemSelected: widget.onItemSelected, isCollapsed: _isCollapsed),
          _SidebarItem(icon: Icons.settings, title: 'Settings', index: 4, selectedIndex: widget.selectedIndex, onItemSelected: widget.onItemSelected, isCollapsed: _isCollapsed),
          const Spacer(),
          Padding(
            padding: EdgeInsets.all(_isCollapsed ? 16.0 : 24.0),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, color: AppColors.textPrimary),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('Logout', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
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
  final bool isCollapsed;

  const _SidebarItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
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
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected ? const Border(right: BorderSide(color: AppColors.primary, width: 4)) : null,
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          ),
          child: OverflowBox(
            maxWidth: 250 - (isCollapsed ? 0 : 48),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, color: isSelected ? AppColors.primary : AppColors.secondary, size: 24),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
