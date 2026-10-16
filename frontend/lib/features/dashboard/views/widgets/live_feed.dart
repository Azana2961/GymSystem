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
                  String status = 'Active';
                  Color statusColor = AppColors.success;
                  
                  if (attendance.member.isPaymentPending) {
                    status = 'Overdue';
                    statusColor = AppColors.error;
                  } else {
                    final daysToExpire = attendance.member.expiryDate.difference(DateTime.now()).inDays;
                    if (daysToExpire < 0) {
                      status = 'Overdue';
                      statusColor = AppColors.error;
                    } else if (daysToExpire <= 5) {
                      status = 'Expiring Soon';
                      statusColor = AppColors.warning;
                    }
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${attendance.member.id}'),
                      backgroundColor: AppColors.border,
                    ),
                    title: Text(attendance.member.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text('${attendance.checkInTime.hour}:${attendance.checkInTime.minute.toString().padLeft(2, '0')} - ID: ${attendance.member.id}'),
                    trailing: Chip(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      label: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
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
