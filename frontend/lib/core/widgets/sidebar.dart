import 'dart:ui';
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

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth = 240.0;
  static const double _collapsedWidth = 68.0;

  @override
  void initState() {
    super.initState();
    // 240ms duration with luxurious Apple/Linear cubic bezier easing
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0), // Fast launch, silky smooth deceleration
      reverseCurve: const Cubic(0.25, 0.1, 0.25, 1.0),
    );

    _widthAnimation = Tween<double>(
      begin: _expandedWidth,
      end: _collapsedWidth,
    ).animate(_curveAnimation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    if (_controller.isAnimating) return;
    if (_controller.value == 0.0) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/la_fitness_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.fitness_center,
            color: AppColors.primary,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    final double headerHeight = lerpDouble(92.0, 68.0, progress)!;

    return SizedBox(
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Logo: Pinned smoothly between collapsed center (15px) and expanded (14px)
          Positioned(
            left: lerpDouble(15.0, 14.0, progress)!,
            top: 15,
            child: Tooltip(
              message: progress < 0.3 ? 'Lá Fitness' : '',
              child: _buildLogo(38),
            ),
          ),

          // Title & Subtitle: Glides in with elegant translation & opacity
          if (progress > 0.12)
            Positioned(
              left: 64,
              top: 15,
              right: 42,
              child: Transform.translate(
                offset: Offset(-10.0 * (1.0 - progress), 0),
                child: Opacity(
                  opacity: ((progress - 0.12) / 0.88).clamp(0.0, 1.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lá Fitness',
                        style: TextStyle(
                          fontFamily: 'SegoeScript',
                          color: AppColors.primary,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      const Text(
                        'GYM MANAGEMENT',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Collapse Button in expanded mode (pinned at right: 6)
          if (progress > 0.4)
            Positioned(
              right: 6,
              top: 15,
              child: Opacity(
                opacity: ((progress - 0.4) / 0.6).clamp(0.0, 1.0),
                child: IconButton(
                  tooltip: 'Collapse Sidebar',
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  onPressed: _toggleCollapse,
                ),
              ),
            ),

          // Expand Button in collapsed mode (centered below the logo)
          if (progress < 0.35)
            Positioned(
              left: 0,
              top: 56,
              width: 68,
              child: Opacity(
                opacity: ((0.35 - progress) / 0.35).clamp(0.0, 1.0),
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Expand Sidebar',
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: _toggleCollapse,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom divider in header
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(color: AppColors.border, height: 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final currentWidth = _widthAnimation.value;
        // progress: 1.0 = fully expanded (240px), 0.0 = fully collapsed (68px)
        final progress = (1.0 - _curveAnimation.value).clamp(0.0, 1.0);

        return RepaintBoundary(
          child: Container(
            width: currentWidth,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border, width: 1)),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(progress),
                const SizedBox(height: 12),

                // Navigation Menu Items
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  index: 0,
                  selectedIndex: widget.selectedIndex,
                  onItemSelected: widget.onItemSelected,
                  progress: progress,
                ),
                _SidebarItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Members',
                  index: 1,
                  selectedIndex: widget.selectedIndex,
                  onItemSelected: widget.onItemSelected,
                  progress: progress,
                ),
                _SidebarItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'Analytics',
                  index: 2,
                  selectedIndex: widget.selectedIndex,
                  onItemSelected: widget.onItemSelected,
                  progress: progress,
                ),
                _SidebarItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  index: 3,
                  selectedIndex: widget.selectedIndex,
                  onItemSelected: widget.onItemSelected,
                  progress: progress,
                ),

                const Spacer(),
                // Clean bottom - admin profile widget removed
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int index;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final double progress; // 0.0 = collapsed, 1.0 = expanded

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final isCollapsed = progress <= 0.05;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: Tooltip(
        message: isCollapsed ? title : '',
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onItemSelected(index),
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppColors.primary.withValues(alpha: 0.08),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                border: isSelected
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Active vertical notch (gives high-end luxury feel)
                    if (isSelected)
                      Positioned(
                        left: 0,
                        top: 10,
                        bottom: 10,
                        width: 3.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Icon: Exactly centered in the 48px box (width 68 - padding 20 = 48)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 48,
                      child: Center(
                        child: Icon(
                          icon,
                          color: isSelected ? AppColors.primary : AppColors.secondary,
                          size: 22,
                        ),
                      ),
                    ),

                    // Title with smooth glide-in translation & opacity
                    if (progress > 0.08)
                      Positioned(
                        left: 48,
                        top: 0,
                        bottom: 0,
                        right: 8,
                        child: Transform.translate(
                          offset: Offset(-8.0 * (1.0 - progress), 0),
                          child: Opacity(
                            opacity: ((progress - 0.08) / 0.92).clamp(0.0, 1.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
