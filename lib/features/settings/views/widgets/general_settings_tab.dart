import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Gym Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gym Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Printed on receipts and member invoices.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Gym Name', 'e.g., Iron Paradise Gym')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Phone Number', 'e.g., 0300-1234567')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Email Address', 'e.g., info@ironparadise.com')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Tax ID / NTN', 'e.g., 1234567-8')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Street Address', 'e.g., 123 Main St, Lahore', maxLines: 2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // System Configurations (Localization)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Localization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Set regional formats for currency and time.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: 'PKR',
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              items: const [
                                DropdownMenuItem(value: 'PKR', child: Text('Pakistani Rupee (PKR)')),
                                DropdownMenuItem(value: 'USD', child: Text('US Dollar (USD)')),
                                DropdownMenuItem(value: 'INR', child: Text('Indian Rupee (INR)')),
                              ],
                              onChanged: (v) {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Timezone', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: 'Asia/Karachi',
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              items: const [
                                DropdownMenuItem(value: 'Asia/Karachi', child: Text('(GMT+5) Islamabad, Karachi')),
                                DropdownMenuItem(value: 'Asia/Dubai', child: Text('(GMT+4) Abu Dhabi, Muscat')),
                                DropdownMenuItem(value: 'GMT', child: Text('GMT Standard Time')),
                              ],
                              onChanged: (v) {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Database Management (Crucial)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('Database Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Secure your local SQLite data. Backup to a USB drive or Google Drive regularly.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.backup),
                          label: const Text('Backup Database'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore Database'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Last backup: 2 hours ago (Auto-backup enabled)', style: TextStyle(fontSize: 12, color: AppColors.success)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48), // Padding for sticky bottom bar
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
