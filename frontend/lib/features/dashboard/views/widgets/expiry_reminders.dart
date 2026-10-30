import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/services/api_service.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class ReminderItem {
  final String id;
  final String name;
  final String phone;
  final String plan;
  final DateTime expiryDate;

  /// 'idle' | 'queued' | 'sending' | 'sent'
  String queueState;
  double? activeDelaySec;
  DateTime? queuedAt;
  DateTime? sentAt;
  String sentChannel;

  ReminderItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.plan,
    required this.expiryDate,
    this.queueState = 'idle',
    this.activeDelaySec,
    this.queuedAt,
    this.sentAt,
    this.sentChannel = 'WhatsApp',
  });

  bool get isSent => queueState == 'sent';
  bool get isQueued => queueState == 'queued';
  bool get isSending => queueState == 'sending';
  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

class ExpiryRemindersWidget extends StatefulWidget {
  const ExpiryRemindersWidget({super.key});

  @override
  State<ExpiryRemindersWidget> createState() => _ExpiryRemindersWidgetState();
}

class _ExpiryRemindersWidgetState extends State<ExpiryRemindersWidget> {
  final MembersProvider _membersProvider = MembersProvider.instance;
  List<ReminderItem> _reminders = [];
  Timer? _livePollTimer;
  int _totalBatchQueued = 0;
  int _batchSentCount = 0;

  @override
  void initState() {
    super.initState();
    _initData();
    _membersProvider.addListener(_onMembersUpdated);
    AppSettings.instance.addListener(_onSettingsUpdated);
    // Check if backend already has active queue items on load
    _syncLiveQueueFromServer();
  }

  @override
  void dispose() {
    _livePollTimer?.cancel();
    _membersProvider.removeListener(_onMembersUpdated);
    AppSettings.instance.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onSettingsUpdated() {
    if (mounted) setState(() {});
  }

  String _normalizePhone(String raw) {
    var clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('03')) {
      clean = '92${clean.substring(1)}';
    }
    return clean;
  }

  void _onMembersUpdated() {
    if (!mounted) return;
    // Preserve existing queue/sent states when member list updates
    final existingStates = <String, ReminderItem>{
      for (final r in _reminders) r.id: r,
    };
    setState(() {
      _initData(preserveFrom: existingStates);
    });
  }

  void _initData({Map<String, ReminderItem>? preserveFrom}) {
    final members = _membersProvider.allMembers;
    final dueMembers = members.where((m) {
      final days = m.expiryDate.difference(DateTime.now()).inDays;
      return m.isPaymentPending || m.isExpired || days <= 7;
    }).toList();

    if (dueMembers.isNotEmpty) {
      _reminders = dueMembers.map((m) {
        final prev = preserveFrom?[m.id];
        return ReminderItem(
          id: m.id,
          name: m.name,
          phone: m.phone ?? '+92 300 0000000',
          plan: m.plan,
          expiryDate: m.expiryDate,
          queueState: prev?.queueState ?? 'idle',
          activeDelaySec: prev?.activeDelaySec,
          queuedAt: prev?.queuedAt,
          sentAt: prev?.sentAt,
          sentChannel: prev?.sentChannel ?? 'WhatsApp',
        );
      }).toList();
    } else {
      _reminders = [
        ReminderItem(
          id: 'M002',
          name: 'Ayesha Khan',
          phone: '+92 321 4589211',
          plan: 'Silver Plan',
          expiryDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        ReminderItem(
          id: 'M004',
          name: 'Usman Khalid',
          phone: '+92 301 7748123',
          plan: 'Basic Plan',
          expiryDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
    }
  }

  List<ReminderItem> get _pendingList =>
      _reminders.where((r) => r.queueState != 'sent').toList();

  List<ReminderItem> get _sentList {
    final list = _reminders.where((r) => r.queueState == 'sent').toList();
    list.sort((a, b) =>
        (b.sentAt ?? DateTime.now()).compareTo(a.sentAt ?? DateTime.now()));
    return list;
  }

  bool get _hasActiveQueue =>
      _reminders.any((r) => r.queueState == 'queued' || r.queueState == 'sending');

  ReminderItem? get _currentlySendingItem {
    for (final r in _reminders) {
      if (r.queueState == 'sending') return r;
    }
    for (final r in _reminders) {
      if (r.queueState == 'queued') return r;
    }
    return null;
  }

  String _buildMessageForItem(ReminderItem item) {
    final settings = AppSettings.instance;
    final dateStr = item.expiryDate.toIso8601String().split('T')[0];
    final template = item.isExpired ? settings.templateExpired : settings.templateDue;
    return settings.renderTemplate(template, {
      'name': item.name,
      'plan': item.plan,
      'expiry_date': dateStr,
      'id': item.id,
    });
  }

  Future<void> _sendAllReminders() async {
    if (!AppSettings.instance.sendExpiryAlert) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry Reminders are turned OFF in Settings. Toggle them ON in Settings to send alerts.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final idleItems = _reminders.where((r) => r.queueState == 'idle').toList();
    if (idleItems.isEmpty) {
      if (_hasActiveQueue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminders are already in the live queue and sending!'),
            backgroundColor: AppColors.surfaceLight,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending reminders to dispatch.'),
            backgroundColor: AppColors.surfaceLight,
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    setState(() {
      _totalBatchQueued = idleItems.length;
      _batchSentCount = 0;
      for (int i = 0; i < idleItems.length; i++) {
        idleItems[i].queueState = i == 0 ? 'sending' : 'queued';
        idleItems[i].queuedAt = now;
      }
    });

    // Enqueue each reminder with the user's customized template from Settings
    for (final item in idleItems) {
      final msg = _buildMessageForItem(item);
      await ApiService.instance.sendWhatsAppMessage(
        memberId: item.id,
        phone: item.phone,
        text: msg,
        type: 'expiry_alert',
      );
    }

    _startLiveQueuePolling();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1B20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⚡ ${idleItems.length} reminders added to Live Queue! Watch them move to Sent as each completes.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSingle(ReminderItem item) async {
    if (!AppSettings.instance.sendExpiryAlert) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry Reminders are turned OFF in Settings. Toggle them ON in Settings to send alerts.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (item.queueState != 'idle') return;

    final now = DateTime.now();
    final anySending = _reminders.any((r) => r.queueState == 'sending');

    setState(() {
      if (!_hasActiveQueue) {
        _totalBatchQueued = 1;
        _batchSentCount = 0;
      } else {
        _totalBatchQueued++;
      }
      item.queueState = anySending ? 'queued' : 'sending';
      item.queuedAt = now;
    });

    final msg = _buildMessageForItem(item);
    await ApiService.instance.sendWhatsAppMessage(
      memberId: item.id,
      phone: item.phone,
      text: msg,
      type: 'expiry_alert',
    );

    _startLiveQueuePolling();
  }

  void _startLiveQueuePolling() {
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _syncLiveQueueFromServer();
    });
  }

  Future<void> _syncLiveQueueFromServer() async {
    if (!mounted) return;

    final statusData = await ApiService.instance.getWhatsAppStatus();
    if (!mounted) return;

    if (statusData != null) {
      final currentTask = statusData['currentTask'] as Map<String, dynamic>?;
      final recentQueue = (statusData['recentQueue'] is List)
          ? List<Map<String, dynamic>>.from(statusData['recentQueue'] as List)
          : <Map<String, dynamic>>[];

      final activeMemberId = currentTask?['memberId']?.toString();
      final activePhone = currentTask?['phone'] != null
          ? _normalizePhone(currentTask!['phone'].toString())
          : null;
      final activeDelay = (currentTask?['delaySec'] is num)
          ? (currentTask!['delaySec'] as num).toDouble()
          : null;

      bool changed = false;

      for (final item in _reminders) {
        if (item.queueState == 'idle' || item.queueState == 'sent') continue;

        final itemPhoneNorm = _normalizePhone(item.phone);

        // Find latest matching queue entry from backend
        Map<String, dynamic>? matchedRow;
        for (final q in recentQueue) {
          final qMemberId = q['member_id']?.toString();
          final qPhone = _normalizePhone(q['recipient_phone']?.toString() ?? '');
          if ((qMemberId != null && qMemberId == item.id) ||
              (qPhone.isNotEmpty && qPhone == itemPhoneNorm)) {
            matchedRow = q;
            break; // recentQueue is ordered by id DESC, so first match is newest
          }
        }

        if (matchedRow != null) {
          final qStatus = matchedRow['status']?.toString() ?? 'pending';
          if (qStatus == 'sent') {
            item.queueState = 'sent';
            item.sentAt = DateTime.now();
            item.activeDelaySec = null;
            _batchSentCount++;
            changed = true;
            continue;
          }
        }

        // Check if this item is currently the active task being delayed/sent
        final isCurrent = (activeMemberId != null && activeMemberId == item.id) ||
            (activePhone != null && activePhone.isNotEmpty && activePhone == itemPhoneNorm);

        if (isCurrent) {
          if (item.queueState != 'sending' || item.activeDelaySec != activeDelay) {
            item.queueState = 'sending';
            item.activeDelaySec = activeDelay;
            changed = true;
          }
        } else if (item.queueState == 'sending' && currentTask != null) {
          item.queueState = 'queued';
          item.activeDelaySec = null;
          changed = true;
        }
      }

      // Ensure at least the first queued item shows 'sending' if worker is busy
      if (!_reminders.any((r) => r.queueState == 'sending')) {
        final firstQueued = _reminders.where((r) => r.queueState == 'queued').firstOrNull;
        if (firstQueued != null) {
          firstQueued.queueState = 'sending';
          firstQueued.activeDelaySec = activeDelay;
          changed = true;
        }
      }

      if (changed && mounted) {
        setState(() {});
      }
    } else {
      // Offline fallback simulation progression if backend is unreachable
      final sendingItem = _currentlySendingItem;
      if (sendingItem != null &&
          sendingItem.queuedAt != null &&
          DateTime.now().difference(sendingItem.queuedAt!).inSeconds >= 6) {
        setState(() {
          sendingItem.queueState = 'sent';
          sendingItem.sentAt = DateTime.now();
          _batchSentCount++;
          final nextQueued = _reminders.where((r) => r.queueState == 'queued').firstOrNull;
          if (nextQueued != null) {
            nextQueued.queueState = 'sending';
            nextQueued.queuedAt = DateTime.now();
          }
        });
      }
    }

    if (!_hasActiveQueue) {
      _livePollTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingList;
    final sent = _sentList;
    final activeItem = _currentlySendingItem;
    final queuedItems = pending.where((r) => r.isQueued || r.isSending).toList();

    return Card(
      child: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Title and Send Reminders button
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.schedule_send_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expiry Reminders',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !AppSettings.instance.sendExpiryAlert
                                    ? 'Paused (Turned OFF in Settings)'
                                    : (_hasActiveQueue
                                        ? 'Live Anti-Ban Queue Active (${queuedItems.length} remaining)'
                                        : 'Automated Membership Retention'),
                                style: TextStyle(
                                  color: !AppSettings.instance.sendExpiryAlert
                                      ? AppColors.warning
                                      : (_hasActiveQueue ? AppColors.primary : AppColors.textMuted),
                                  fontSize: 11,
                                  fontWeight: (_hasActiveQueue || !AppSettings.instance.sendExpiryAlert)
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Send Reminders Button (Yellow Theme)
                  ElevatedButton.icon(
                    onPressed: (_hasActiveQueue || !AppSettings.instance.sendExpiryAlert) ? null : _sendAllReminders,
                    icon: _hasActiveQueue
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : Icon(
                            !AppSettings.instance.sendExpiryAlert ? Icons.notifications_off_rounded : Icons.send_rounded,
                            size: 14,
                            color: !AppSettings.instance.sendExpiryAlert ? AppColors.textMuted : Colors.black,
                          ),
                    label: Text(
                      !AppSettings.instance.sendExpiryAlert
                          ? 'Reminders Off'
                          : (_hasActiveQueue
                              ? 'In Queue (${queuedItems.length})'
                              : 'Send Reminders'),
                      style: TextStyle(
                        color: !AppSettings.instance.sendExpiryAlert
                            ? AppColors.textMuted
                            : (_hasActiveQueue ? AppColors.primary : Colors.black),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

              // Live Active Sending Banner (shown when queue is processing)
              if (_hasActiveQueue && activeItem != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sending to ${activeItem.phone} (${activeItem.name})...',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeItem.activeDelaySec != null
                                  ? 'Anti-ban human delay (${activeItem.activeDelaySec}s) • Will move to Sent automatically'
                                  : 'Processing in WhatsApp queue • Moving to Sent dynamically...',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_totalBatchQueued > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            '$_batchSentCount/$_totalBatchQueued Sent',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Tab Bar: Pending vs Sent
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Pending / Queue', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pending.isNotEmpty
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: pending.isNotEmpty ? AppColors.primary : AppColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${pending.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: pending.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Sent', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: sent.isNotEmpty
                                  ? AppColors.success.withValues(alpha: 0.18)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sent.isNotEmpty ? AppColors.success : AppColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${sent.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sent.isNotEmpty ? AppColors.success : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    // --- PENDING / LIVE QUEUE TAB ---
                    pending.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
                                const SizedBox(height: 10),
                                const Text(
                                  'All reminders sent!',
                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Switch to the Sent tab to view delivered messages.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => setState(() => _initData()),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Reset List', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: pending.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                            itemBuilder: (context, index) {
                              final item = pending[index];
                              final isExpired = item.isExpired;
                              final days = item.daysRemaining.abs();
                              final statusText = isExpired
                                  ? (days == 0 ? 'Expired today' : 'Expired $days days ago')
                                  : (days == 0 ? 'Expires today' : 'Expires in $days days');
                              final statusColor = isExpired ? AppColors.error : AppColors.warning;
                              final queueIdx = queuedItems.indexOf(item);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: item.isSending
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: item.isSending
                                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: item.isSending
                                          ? AppColors.primary.withValues(alpha: 0.2)
                                          : AppColors.surfaceLight,
                                      child: item.isSending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : Text(
                                              item.name.isNotEmpty ? item.name[0] : 'M',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isExpired ? AppColors.error : AppColors.primary,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                    fontSize: 14,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: statusColor.withValues(alpha: 0.4),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone_iphone_rounded,
                                                size: 12,
                                                color: item.isSending ? AppColors.primary : AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '${item.phone} • ${item.plan}',
                                                  style: TextStyle(
                                                    color: item.isSending
                                                        ? AppColors.primary
                                                        : AppColors.textMuted,
                                                    fontWeight: item.isSending
                                                        ? FontWeight.w700
                                                        : FontWeight.normal,
                                                    fontSize: 11,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Live State Action / Status Pill
                                    if (item.isSending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.primary),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 11,
                                              height: 11,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              item.activeDelaySec != null
                                                  ? 'Sending (${item.activeDelaySec}s)'
                                                  : 'Sending...',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (item.isQueued)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.hourglass_top_rounded, size: 13, color: AppColors.warning),
                                            const SizedBox(width: 4),
                                            Text(
                                              queueIdx >= 0 ? 'In Queue (#${queueIdx + 1})' : 'In Queue',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Tooltip(
                                        message: 'Send WhatsApp reminder',
                                        child: InkWell(
                                          onTap: () => _sendSingle(item),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.send_outlined, size: 13, color: AppColors.primary),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Remind',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                    // --- SENT TAB ---
                    sent.isEmpty
                        ? const Center(
                            child: Text(
                              'No sent reminders logged yet.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: sent.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                            itemBuilder: (context, index) {
                              final item = sent[index];
                              final timeStr = item.sentAt != null
                                  ? (item.sentAt!.difference(DateTime.now()).inMinutes.abs() < 2
                                      ? 'Just now'
                                      : 'Today at ${item.sentAt!.hour.toString().padLeft(2, '0')}:${item.sentAt!.minute.toString().padLeft(2, '0')}')
                                  : 'Recently';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.success.withValues(alpha: 0.15),
                                      child: const Icon(
                                        Icons.mark_chat_read_rounded,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${item.phone} • ${item.plan}',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.done_all_rounded, size: 14, color: AppColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.sentChannel,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
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
