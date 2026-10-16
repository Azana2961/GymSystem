import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class IntegrationsSettingsTab extends StatefulWidget {
  const IntegrationsSettingsTab({super.key});

  @override
  State<IntegrationsSettingsTab> createState() => _IntegrationsSettingsTabState();
}

class _IntegrationsSettingsTabState extends State<IntegrationsSettingsTab> {
  bool _sendExpiryAlert = true;
  bool _sendPaymentSuccess = true;
  bool _sendBirthdayWishes = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WhatsApp / SMS Gateway
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WhatsApp / SMS Gateway', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Link your device or enter API keys for automated messaging.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gateway Provider', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: 'Twilio (SMS)',
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Twilio (SMS)', child: Text('Twilio (SMS)')),
                                DropdownMenuItem(value: 'WhatsApp Cloud API', child: Text('WhatsApp Cloud API')),
                                DropdownMenuItem(value: 'Local Android Device', child: Text('Local Android Device')),
                              ],
                              onChanged: (v) {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('API Key / Token', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              obscureText: true,
                              initialValue: 'sk_test_1234567890abcdef',
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test Message'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Alert Preferences
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alert Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Configure which automated messages are sent to members.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  _buildToggle(
                    'Expiry Reminders',
                    'Send message 3 days before membership expiry.',
                    _sendExpiryAlert,
                    (v) => setState(() => _sendExpiryAlert = v),
                  ),
                  const Divider(),
                  _buildToggle(
                    'Payment Receipts',
                    'Send message on successful payment with invoice link.',
                    _sendPaymentSuccess,
                    (v) => setState(() => _sendPaymentSuccess = v),
                  ),
                  const Divider(),
                  _buildToggle(
                    'Birthday Wishes',
                    'Send an automated birthday wish in the morning.',
                    _sendBirthdayWishes,
                    (v) => setState(() => _sendBirthdayWishes = v),
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

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
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
