import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'widgets/general_settings_tab.dart';
import 'widgets/memberships_settings_tab.dart';
import 'widgets/hardware_settings_tab.dart';
import 'widgets/staff_settings_tab.dart';
import 'widgets/integrations_settings_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  dividerColor: AppColors.border,
                  tabs: const [
                    Tab(text: 'General'),
                    Tab(text: 'Memberships'),
                    Tab(text: 'Hardware & Devices'),
                    Tab(text: 'Staff & Security'),
                    Tab(text: 'Integrations & Alerts'),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      GeneralSettingsTab(),
                      MembershipsSettingsTab(),
                      HardwareSettingsTab(),
                      StaffSettingsTab(),
                      IntegrationsSettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sticky Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                child: const Text('Discard Changes'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
