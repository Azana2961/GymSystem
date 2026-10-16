import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class MembershipsSettingsTab extends StatefulWidget {
  const MembershipsSettingsTab({super.key});

  @override
  State<MembershipsSettingsTab> createState() => _MembershipsSettingsTabState();
}

class _MembershipsSettingsTabState extends State<MembershipsSettingsTab> {
  bool _enableJoiningFee = true;
  double _joiningFeeAmount = 5000;

  final List<Map<String, dynamic>> _plans = [
    {'name': '1 Month Standard', 'price': 8000, 'days': 30},
    {'name': '3 Month Student', 'price': 18000, 'days': 90},
    {'name': 'Annual VIP', 'price': 65000, 'days': 365},
  ];

  void _addPlan() {
    setState(() {
      _plans.add({'name': 'New Plan', 'price': 0, 'days': 30});
    });
  }

  void _removePlan(int index) {
    setState(() {
      _plans.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admission Fee Toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admission / Registration Fee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Automatically add a one-time joining fee to new member invoices.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Switch(
                        value: _enableJoiningFee,
                        onChanged: (v) => setState(() => _enableJoiningFee = v),
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text('Enable Joining Fee', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 48),
                      if (_enableJoiningFee)
                        Expanded(
                          child: TextFormField(
                            initialValue: _joiningFeeAmount.toInt().toString(),
                            decoration: const InputDecoration(
                              labelText: 'Joining Fee Amount (PKR)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Plan Builder
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
                          const Text('Plan Builder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Define your membership tiers, pricing, and exact durations.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addPlan,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Plan'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _plans.length,
                    separatorBuilder: (context, index) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: plan['name'],
                              decoration: const InputDecoration(labelText: 'Plan Name', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: plan['price'].toString(),
                              decoration: const InputDecoration(labelText: 'Price (PKR)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: plan['days'].toString(),
                              decoration: const InputDecoration(labelText: 'Duration (Days)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: () => _removePlan(index),
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            tooltip: 'Delete Plan',
                          ),
                        ],
                      );
                    },
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
