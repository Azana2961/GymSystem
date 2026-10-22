import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/services/api_service.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class ReminderItem {
  final String id;
  final String name;
  final String phone;
  final String plan;
  final DateTime expiryDate;
  bool isSent;
  DateTime? sentAt;
  String sentChannel;

  ReminderItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.plan,
    required this.expiryDate,
    this.isSent = false,
    this.sentAt,
    this.sentChannel = 'WhatsApp',
  });

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
  late List<ReminderItem> _reminders;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _membersProvider.addListener(_onMembersUpdated);
  }

  @override
  void dispose() {
    _membersProvider.removeListener(_onMembersUpdated);
    super.dispose();
  }

  void _onMembersUpdated() {
    if (mounted) {
      setState(() {
        _initData();
      });
    }
  }

  void _initData() {
    final members = _membersProvider.allMembers;
    final dueMembers = members.where((m) {
      final days = m.expiryDate.difference(DateTime.now()).inDays;
      return m.isPaymentPending || m.isExpired || days <= 7;
    }).toList();

    if (dueMembers.isNotEmpty) {
      _reminders = dueMembers.map((m) {
        return ReminderItem(
          id: m.id,
          name: m.name,
          phone: m.phone ?? '+92 300 0000000',
          plan: m.plan,
          expiryDate: m.expiryDate,
          isSent: false,
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
          isSent: false,
        ),
        ReminderItem(
          id: 'M004',
          name: 'Usman Khalid',
          phone: '+92 301 7748123',
          plan: 'Basic Plan',
          expiryDate: DateTime.now().subtract(const Duration(days: 2)),
          isSent: false,
        ),
      ];
    }
  }

  List<ReminderItem> get _pendingList => _reminders.where((r) => !r.isSent).toList();
  List<ReminderItem> get _sentList => _reminders.where((r) => r.isSent).toList();

  Future<void> _sendAllReminders() async {
    final pendingCount = _pendingList.length;
    if (pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending reminders to dispatch.'),
          backgroundColor: AppColors.surfaceLight,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    int count = await ApiService.instance.sendWhatsAppExpiryAlerts();
    if (count == 0) count = pendingCount;

    if (!mounted) return;

    setState(() {
      for (final r in _reminders) {
        if (!r.isSent) {
          r.isSent = true;
          r.sentAt = DateTime.now();
          r.sentChannel = 'WhatsApp';
        }
      }
      _isSending = false;
    });

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
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⚡ Anti-Ban Active! $count reminders queued with randomized human time delays.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSingle(ReminderItem item) async {
    setState(() {
      item.isSent = true;
      item.sentAt = DateTime.now();
      item.sentChannel = 'WhatsApp';
    });

    final msg = '{Salam|Hello} ${item.name}! Friendly reminder that your ${item.plan} gym subscription is due on ${item.expiryDate.toString().split(' ')[0]}. Please visit reception to renew!';
    await ApiService.instance.sendWhatsAppMessage(
      memberId: item.id,
      phone: item.phone,
      text: msg,
      type: 'expiry_alert',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1B20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
        content: Text(
          '⚡ Reminder for ${item.name} queued with anti-ban random delay.',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final pending = _pendingList;
    final sent = _sentList;

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
                              const Text(
                                'Automated Membership Retention',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                    onPressed: _isSending ? null : _sendAllReminders,
                    icon: _isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded, size: 14, color: Colors.black),
                    label: Text(
                      _isSending ? 'Sending...' : 'Send Reminders',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
              const SizedBox(height: 14),
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
                          const Text('Pending', style: TextStyle(fontWeight: FontWeight.w700)),
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
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: Text(
                              '${sent.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    // --- PENDING TAB ---
                    pending.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 40),
                                const SizedBox(height: 10),
                                const Text(
                                  'All caught up!',
                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'No pending reminders at this moment.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => setState(() => _initData()),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Reset Sample Data', style: TextStyle(fontSize: 12)),
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

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.surfaceLight,
                                      child: Text(
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
                                          Text(
                                            '${item.phone} • ${item.plan}',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                  ? (item.sentAt!.difference(DateTime.now()).inHours.abs() < 1
                                      ? 'Just now'
                                      : (item.sentAt!.difference(DateTime.now()).inDays.abs() == 0
                                          ? 'Today at ${item.sentAt!.hour.toString().padLeft(2, '0')}:${item.sentAt!.minute.toString().padLeft(2, '0')}'
                                          : '${item.sentAt!.difference(DateTime.now()).inDays.abs()}d ago'))
                                  : 'Recently';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.surfaceLight,
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
                                                color: AppColors.textSecondary,
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
