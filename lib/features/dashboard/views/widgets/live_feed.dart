import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';

class LiveFeedWidget extends StatelessWidget {
  const LiveFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Attendance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: DummyData.recentCheckIns.length,
                itemBuilder: (context, index) {
                  final attendance = DummyData.recentCheckIns[index];
                  final bool isValid = !attendance.member.isPaymentPending && attendance.member.expiryDate.isAfter(DateTime.now());
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.border,
                      child: Text(attendance.member.name[0], style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    title: Text(attendance.member.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text('${attendance.checkInTime.hour}:${attendance.checkInTime.minute.toString().padLeft(2, '0')} - ID: ${attendance.member.id}'),
                    trailing: Chip(
                      backgroundColor: isValid ? AppColors.success.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2),
                      label: Text(isValid ? 'Valid' : 'Invalid', style: TextStyle(color: isValid ? AppColors.success : AppColors.error)),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
