import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gym Information', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              _buildTextField('Gym Name', 'IRON CORE FITNESS'),
              const SizedBox(height: 16),
              _buildTextField('Contact Email', 'admin@ironcore.com'),
              const SizedBox(height: 16),
              _buildTextField('Contact Phone', '+1 234 567 890'),
              const SizedBox(height: 16),
              _buildTextField('Address', '123 Muscle Street, Fitness City'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
