import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/dashboard/models/attendance_model.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/services/api_service.dart';

class LiveFeedWidget extends StatefulWidget {
  const LiveFeedWidget({super.key});

  @override
  State<LiveFeedWidget> createState() => _LiveFeedWidgetState();
}

class _LiveFeedWidgetState extends State<LiveFeedWidget> {
  List<AttendanceModel> _feed = [];
  Timer? _poller;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _feed = List.from(DummyData.recentCheckIns);
    _fetchLiveFeed();
    // Poll every 2 seconds for real-time tablet attendance updates
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLiveFeed());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveFeed() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final baseUrl = ApiService.instance.baseUrl;
      final request = await client.getUrl(Uri.parse('$baseUrl/api/attendance/feed?limit=25'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['feed'] is List) {
          final list = (json['feed'] as List).map((item) {
            final parsedTime = DateTime.tryParse(item['scanned_at'] ?? '') ?? DateTime.now();
            final memberExpiry = DateTime.tryParse(item['member_expiry'] ?? '') ?? DateTime.now().add(const Duration(days: 30));
            final isPending = item['status'] == 'due';
            final member = MemberModel(
              id: item['member_id'] ?? item['qr_token'] ?? 'M000',
              name: item['member_name'] ?? 'Member',
              plan: item['plan'] ?? 'Standard Plan',
              expiryDate: memberExpiry,
              isPaymentPending: isPending,
              phone: item['phone'],
            );
            return AttendanceModel(member: member, checkInTime: parsedTime);
          }).toList();

          if (mounted && list.isNotEmpty) {
            setState(() {
              _feed = list;
              _connected = true;
            });
            return;
          }
        }
      }
      if (mounted && !_connected) {
        setState(() => _connected = true);
      }
    } catch (_) {
      if (mounted && _connected) {
        setState(() => _connected = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Attendance', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _connected ? AppColors.success : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _connected ? 'Live Sync' : 'Offline Buffer',
                      style: TextStyle(
                        fontSize: 12,
                        color: _connected ? AppColors.success : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _feed.length,
                itemBuilder: (context, index) {
                  final attendance = _feed[index];
                  String status = 'Active';
                  Color statusColor = AppColors.success;

                  if (attendance.member.isPaymentPending) {
                    status = 'Due Soon';
                    statusColor = AppColors.warning;
                  } else {
                    final daysToExpire = attendance.member.expiryDate.difference(DateTime.now()).inDays;
                    if (daysToExpire < 0) {
                      status = 'Expired';
                      statusColor = AppColors.error;
                    } else if (daysToExpire <= 5) {
                      status = 'Expiring Soon';
                      statusColor = AppColors.warning;
                    }
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface,
                      child: Text(
                        attendance.member.name.isNotEmpty ? attendance.member.name[0] : 'M',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    title: Text(
                      attendance.member.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${attendance.checkInTime.hour.toString().padLeft(2, '0')}:${attendance.checkInTime.minute.toString().padLeft(2, '0')} - ID: ${attendance.member.id}',
                    ),
                    trailing: Chip(
                      backgroundColor: statusColor.withValues(alpha: 0.12),
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
