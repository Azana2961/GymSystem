import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';

class CriticalAlertsWidget extends StatelessWidget {
  const CriticalAlertsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine expiring memberships
    final expiringMembers = DummyData.members.where((m) {
      final days = m.expiryDate.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 5;
    }).toList();

    final activeTrainers = DummyData.trainers.where((t) => t.isClockedIn).toList();

    return Card(
      child: DefaultTabController(
        length: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Critical Alerts & Exceptions', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: 'Failed Access'),
                  Tab(text: 'Expiring'),
                  Tab(text: 'Trainers'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.error,
                            child: Icon(Icons.cancel, color: Colors.white),
                          ),
                          title: const Text('Failed Access: Alex Brown', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Unpaid Fees - Blocked at turnstile'),
                          trailing: const Text('Just now', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ListView(
                      children: [
                        if (expiringMembers.isEmpty) const Text('No expiring members currently in facility.'),
                        ...expiringMembers.take(3).map((m) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${m.id}'),
                              ),
                              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Expires in ${m.expiryDate.difference(DateTime.now()).inDays} days'),
                              trailing: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.warning,
                                  elevation: 0,
                                ),
                                child: const Text('Renew'),
                              ),
                            )),
                      ],
                    ),
                    ListView(
                      children: [
                        if (activeTrainers.isEmpty) const Text('No trainers currently clocked in.'),
                        ...activeTrainers.map((t) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(t.avatarUrl),
                              ),
                              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(t.specialty),
                              trailing: const Icon(Icons.check_circle, color: AppColors.success),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
