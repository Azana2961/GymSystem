import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class StaffSettingsTab extends StatelessWidget {
  const StaffSettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Staff & Trainer Salaries', style: Theme.of(context).textTheme.titleLarge),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DataTable(
                  headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  columns: const [
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Base Salary')),
                    DataColumn(label: Text('Commission/Hour')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    _buildStaffRow('Senior Trainer', '\$4,000/mo', '\$25/hr'),
                    _buildStaffRow('Junior Trainer', '\$2,500/mo', '\$15/hr'),
                    _buildStaffRow('Yoga Instructor', '\$3,000/mo', '\$30/class'),
                    _buildStaffRow('Front Desk', '\$2,200/mo', '-'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildStaffRow(String role, String base, String commission) {
    return DataRow(
      cells: [
        DataCell(Text(role, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(base)),
        DataCell(Text(commission)),
        DataCell(
          Row(
            children: [
              IconButton(icon: const Icon(Icons.edit, size: 20, color: AppColors.secondary), onPressed: () {}),
              IconButton(icon: const Icon(Icons.delete, size: 20, color: AppColors.error), onPressed: () {}),
            ],
          ),
        ),
      ],
    );
  }
}
