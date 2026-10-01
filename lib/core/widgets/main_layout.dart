import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'package:gym_system/features/dashboard/views/dashboard_screen.dart';
import 'package:gym_system/features/members/views/members_screen.dart';
import 'package:gym_system/features/trainers/views/trainers_screen.dart';
import 'package:gym_system/features/analytics/views/analytics_screen.dart';
import 'package:gym_system/features/settings/views/settings_screen.dart';
import 'package:gym_system/core/theme/colors.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const MembersScreen(),
    const TrainersScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
