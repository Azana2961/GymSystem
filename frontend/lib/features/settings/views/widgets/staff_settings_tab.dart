import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class StaffSettingsTab extends StatefulWidget {
  const StaffSettingsTab({super.key});

  @override
  State<StaffSettingsTab> createState() => _StaffSettingsTabState();
}

class _StaffSettingsTabState extends State<StaffSettingsTab> {
  bool _canDeleteMember = false;
  bool _canEditPayment = false;
  bool _canApplyDiscount = false;
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PIN Protection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Master PIN Protection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Set a 4-digit Master PIN required to access Settings or perform critical actions.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '****',
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Current Master PIN', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New Master PIN', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirm New PIN', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Role Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Role Management (Access Control)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Create users and assign Admin or Front Desk roles.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add User'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DataTable(
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      DataRow(cells: [
                        const DataCell(Text('Ali Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('Admin (Full Access)', style: TextStyle(color: AppColors.success))),
                        const DataCell(Text('Active')),
                        DataCell(IconButton(icon: const Icon(Icons.edit), onPressed: () {})),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Ahmed Desk', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('Front Desk')),
                        const DataCell(Text('Active')),
                        DataCell(IconButton(icon: const Icon(Icons.edit), onPressed: () {})),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Front Desk Permissions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Front Desk Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Lock down what Front Desk staff are allowed to do to prevent fraud.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  _buildPermissionToggle(
                    'Delete Member Records',
                    'Allow front desk to permanently delete members.',
                    _canDeleteMember,
                    (v) => setState(() => _canDeleteMember = v),
                  ),
                  const Divider(),
                  _buildPermissionToggle(
                    'Edit Payment History',
                    'Allow front desk to modify past invoices or payment records.',
                    _canEditPayment,
                    (v) => setState(() => _canEditPayment = v),
                  ),
                  const Divider(),
                  _buildPermissionToggle(
                    'Apply Discounts',
                    'Allow front desk to manually apply custom discounts on plans.',
                    _canApplyDiscount,
                    (v) => setState(() => _canApplyDiscount = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48), // Padding for sticky bottom bar
        ],
      ),
    );
  }

  Widget _buildPermissionToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
