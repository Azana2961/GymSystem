import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 80 : 250,
      color: AppColors.surface,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Logo & App Name
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 16 : 20),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const Icon(Icons.fitness_center, color: AppColors.primary, size: 30),
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
          const SizedBox(height: 16),
          // Collapse / Expand toggle button
          Align(
            alignment: _isCollapsed ? Alignment.center : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 12),
              child: IconButton(
                tooltip: _isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                icon: Icon(
                  _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _isCollapsed = !_isCollapsed;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Menu Items
          _SidebarItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            index: 0,
            selectedIndex: widget.selectedIndex,
            onItemSelected: widget.onItemSelected,
            isCollapsed: _isCollapsed,
          ),
          _SidebarItem(
            icon: Icons.people,
            title: 'Members',
            index: 1,
            selectedIndex: widget.selectedIndex,
            onItemSelected: widget.onItemSelected,
            isCollapsed: _isCollapsed,
          ),
          _SidebarItem(
            icon: Icons.sports_kabaddi,
            title: 'Trainers',
            index: 2,
            selectedIndex: widget.selectedIndex,
            onItemSelected: widget.onItemSelected,
            isCollapsed: _isCollapsed,
          ),
          _SidebarItem(
            icon: Icons.bar_chart,
            title: 'Analytics',
            index: 3,
            selectedIndex: widget.selectedIndex,
            onItemSelected: widget.onItemSelected,
            isCollapsed: _isCollapsed,
          ),
          _SidebarItem(
            icon: Icons.settings,
            title: 'Settings',
            index: 4,
            selectedIndex: widget.selectedIndex,
            onItemSelected: widget.onItemSelected,
            isCollapsed: _isCollapsed,
          ),
          const Spacer(),
          // User profile at the bottom
          Padding(
            padding: EdgeInsets.all(_isCollapsed ? 12.0 : 20.0),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, color: AppColors.textPrimary, size: 20),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Logout',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: isCollapsed ? title : '',
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: () => onItemSelected(index),
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: isSelected
                  ? const Border(right: BorderSide(color: AppColors.primary, width: 4))
                  : null,
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                  size: 24,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
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
