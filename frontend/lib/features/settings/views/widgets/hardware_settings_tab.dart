import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class HardwareSettingsTab extends StatelessWidget {
  const HardwareSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Biometric Scanner
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Biometric Scanner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Configure the USB fingerprint device for member check-ins.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: 'DigitalPersona 4500',
                          decoration: const InputDecoration(labelText: 'Active Scanner', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'DigitalPersona 4500', child: Text('DigitalPersona U.are.U 4500')),
                            DropdownMenuItem(value: 'ZKTeco', child: Text('ZKTeco ZK4500')),
                            DropdownMenuItem(value: 'SecuGen', child: Text('SecuGen Hamster Pro 20')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Test Connection'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Receipt Printer
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receipt Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Configure the thermal printer for payment invoices.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: 'POS-80C',
                          decoration: const InputDecoration(labelText: 'Active Printer', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'POS-80C', child: Text('POS-80C Thermal Printer (USB)')),
                            DropdownMenuItem(value: 'Epson', child: Text('Epson TM-T20III')),
                            DropdownMenuItem(value: 'XPrinter', child: Text('XPrinter XP-58IIH')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: '80mm',
                          decoration: const InputDecoration(labelText: 'Paper Width', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: '58mm', child: Text('58mm')),
                            DropdownMenuItem(value: '80mm', child: Text('80mm')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.print),
                        label: const Text('Print Test Receipt'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Webcam Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Webcam Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Select the front desk webcam to snap member profile photos.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: 'Logitech C920',
                          decoration: const InputDecoration(labelText: 'Active Webcam', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Logitech C920', child: Text('Logitech HD Pro Webcam C920')),
                            DropdownMenuItem(value: 'Integrated', child: Text('Integrated Camera')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Test Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
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
}
