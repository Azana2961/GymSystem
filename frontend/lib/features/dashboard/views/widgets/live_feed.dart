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

  static const Color _visitorColor = Color(0xFF00E5FF);

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
      final request = await client.getUrl(Uri.parse('$baseUrl/api/attendance/feed?limit=60'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['feed'] is List) {
          final list = (json['feed'] as List).map((item) {
            final parsedTime = DateTime.tryParse(item['scanned_at'] ?? '') ?? DateTime.now();
            final memberExpiry =
                DateTime.tryParse(item['member_expiry'] ?? '') ?? DateTime.now().add(const Duration(days: 30));
            final rawStatus = (item['status'] ?? 'paid').toString();
            final isPending = rawStatus == 'due';
            final qrToken = item['qr_token']?.toString();
            final member = MemberModel(
              id: item['member_id'] ?? qrToken ?? 'M000',
              name: item['member_name'] ?? 'Member',
              plan: item['plan'] ?? (rawStatus == 'visitor' ? 'Visitor Pass' : 'Standard Plan'),
              expiryDate: memberExpiry,
              isPaymentPending: isPending,
              phone: item['phone'],
              qrToken: qrToken,
            );
            return AttendanceModel(
              member: member,
              checkInTime: parsedTime,
              statusOverride: rawStatus,
              visitorPhotoUrl: item['visitor_photo']?.toString(),
            );
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

  String _resolvePhotoUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://') || rawUrl.startsWith('data:')) {
      return rawUrl;
    }
    final base = ApiService.instance.baseUrl;
    return '$base${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
  }

  void _showVisitorPhotoDialog(BuildContext context, AttendanceModel item) {
    final rawPhoto = item.visitorPhotoUrl;
    if (rawPhoto == null || rawPhoto.isEmpty) return;
    final resolved = _resolvePhotoUrl(rawPhoto);
    final timeStr =
        '${item.checkInTime.hour.toString().padLeft(2, '0')}:${item.checkInTime.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _visitorColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt_rounded, color: _visitorColor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Visitor Scan Snapshot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: resolved.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(resolved.split(',').last),
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        resolved,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 180,
                          color: AppColors.surfaceLight,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 40),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                item.member.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Visitor Pass (${item.member.qrToken ?? item.member.id}) • Checked in at $timeStr',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _feed.where((a) => a.category == 'active').toList();
    final dueList = _feed.where((a) => a.category == 'due').toList();
    final expiredList = _feed.where((a) => a.category == 'expired').toList();
    final visitorList = _feed.where((a) => a.category == 'visitor').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Live Attendance', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${_feed.length} Scans',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
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
            const SizedBox(height: 14),

            // 4 Categorized Columns: Active | Due | Expired | Visitor
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildAttendanceColumn(
                      title: 'Active',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      items: activeList,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAttendanceColumn(
                      title: 'Due',
                      icon: Icons.schedule_rounded,
                      color: AppColors.warning,
                      items: dueList,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAttendanceColumn(
                      title: 'Expired',
                      icon: Icons.cancel_rounded,
                      color: AppColors.error,
                      items: expiredList,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAttendanceColumn(
                      title: 'Visitor',
                      icon: Icons.camera_alt_rounded,
                      color: _visitorColor,
                      items: visitorList,
                      isVisitorCol: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceColumn({
    required String title,
    required IconData icon,
    required Color color,
    required List<AttendanceModel> items,
    bool isVisitorCol = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.22))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column Items List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        isVisitorCol ? 'No visitor scans' : 'No $title check-ins',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final att = items[index];
                      final timeStr =
                          '${att.checkInTime.hour.toString().padLeft(2, '0')}:${att.checkInTime.minute.toString().padLeft(2, '0')}';
                      final hasPhoto = att.visitorPhotoUrl != null && att.visitorPhotoUrl!.isNotEmpty;

                      return InkWell(
                        onTap: hasPhoto ? () => _showVisitorPhotoDialog(context, att) : null,
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: hasPhoto ? color.withValues(alpha: 0.45) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildAvatar(att, color, hasPhoto),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      att.member.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$timeStr • ${att.member.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    if (hasPhoto) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.photo_camera_rounded, size: 10, color: color),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Tap to view photo',
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AttendanceModel att, Color color, bool hasPhoto) {
    if (hasPhoto) {
      final resolved = _resolvePhotoUrl(att.visitorPhotoUrl!);
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: ClipOval(
          child: resolved.startsWith('data:image')
              ? Image.memory(
                  base64Decode(resolved.split(',').last),
                  fit: BoxFit.cover,
                )
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(Icons.person_rounded, size: 18, color: color),
                ),
        ),
      );
    }

    return CircleAvatar(
      radius: 15,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Text(
        att.member.name.isNotEmpty ? att.member.name[0].toUpperCase() : 'M',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
      ),
    );
  }
}
