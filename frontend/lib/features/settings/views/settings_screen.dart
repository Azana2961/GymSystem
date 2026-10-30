import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings.instance;

  // Membership & Admission Fee
  bool _enableJoiningFee = AppSettings.instance.enableJoiningFee;
  final TextEditingController _joiningFeeController = TextEditingController(
    text: AppSettings.instance.joiningFeeAmount.toInt().toString(),
  );
  List<MembershipPlanConfig> _plans = List<MembershipPlanConfig>.from(AppSettings.instance.plans);

  // Automated WhatsApp & Notifications
  bool _sendExpiryAlert = AppSettings.instance.sendExpiryAlert;
  bool _sendPaymentReceipt = AppSettings.instance.sendPaymentReceipt;
  bool _sendWelcomeMessage = AppSettings.instance.sendWelcomeMessage;
  final TextEditingController _testPhoneController = TextEditingController(text: '+92 300 1234567');
  final TextEditingController _welcomeTemplateCtrl = TextEditingController(text: AppSettings.instance.templateWelcome);
  final TextEditingController _dueTemplateCtrl = TextEditingController(text: AppSettings.instance.templateDue);
  final TextEditingController _expiredTemplateCtrl = TextEditingController(text: AppSettings.instance.templateExpired);
  final TextEditingController _receiptTemplateCtrl = TextEditingController(text: AppSettings.instance.templateReceipt);
  bool _savingTemplates = false;
  Map<String, dynamic>? _realWaStatus;

  // Tablet Kiosk & Network Discovery
  Map<String, dynamic>? _networkInfo;
  List<Map<String, dynamic>> _tabletDevices = [];
  bool _loadingTabletData = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadSettings();
  }

  void _loadSettings() {
    _enableJoiningFee = _settings.enableJoiningFee;
    _joiningFeeController.text = _settings.joiningFeeAmount.toInt().toString();
    _plans = List<MembershipPlanConfig>.from(_settings.plans);
    _sendExpiryAlert = _settings.sendExpiryAlert;
    _sendPaymentReceipt = _settings.sendPaymentReceipt;
    _sendWelcomeMessage = _settings.sendWelcomeMessage;
    _welcomeTemplateCtrl.text = _settings.templateWelcome;
    _dueTemplateCtrl.text = _settings.templateDue;
    _expiredTemplateCtrl.text = _settings.templateExpired;
    _receiptTemplateCtrl.text = _settings.templateReceipt;
    _loadRealWaStatus();
    _loadWaTemplatesFromServer();
    _loadTabletData();
  }

  Future<void> _loadWaTemplatesFromServer() async {
    try {
      final serverSettings = await ApiService.instance.getWhatsAppSettings();
      if (serverSettings != null && mounted) {
        setState(() {
          if (serverSettings['template_welcome'] != null && serverSettings['template_welcome'].toString().isNotEmpty) {
            _settings.templateWelcome = serverSettings['template_welcome'].toString();
            _welcomeTemplateCtrl.text = _settings.templateWelcome;
          }
          if (serverSettings['template_due'] != null && serverSettings['template_due'].toString().isNotEmpty) {
            _settings.templateDue = serverSettings['template_due'].toString();
            _dueTemplateCtrl.text = _settings.templateDue;
          }
          if (serverSettings['template_expired'] != null && serverSettings['template_expired'].toString().isNotEmpty) {
            _settings.templateExpired = serverSettings['template_expired'].toString();
            _expiredTemplateCtrl.text = _settings.templateExpired;
          }
          if (serverSettings['template_receipt'] != null && serverSettings['template_receipt'].toString().isNotEmpty) {
            _settings.templateReceipt = serverSettings['template_receipt'].toString();
            _receiptTemplateCtrl.text = _settings.templateReceipt;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveWaTemplates() async {
    setState(() => _savingTemplates = true);
    _settings.templateWelcome = _welcomeTemplateCtrl.text.trim();
    _settings.templateDue = _dueTemplateCtrl.text.trim();
    _settings.templateExpired = _expiredTemplateCtrl.text.trim();
    _settings.templateReceipt = _receiptTemplateCtrl.text.trim();

    final ok = await ApiService.instance.updateWhatsAppSettings({
      'template_welcome': _settings.templateWelcome,
      'template_due': _settings.templateDue,
      'template_expired': _settings.templateExpired,
      'template_receipt': _settings.templateReceipt,
      'enable_welcome_msg': _sendWelcomeMessage.toString(),
      'enable_expiry_alerts': _sendExpiryAlert.toString(),
      'enable_payment_receipts': _sendPaymentReceipt.toString(),
    });

    if (mounted) {
      setState(() => _savingTemplates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'WhatsApp message templates saved and synced with server!'
                : 'Templates saved locally (server offline).',
          ),
          backgroundColor: ok ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  void _resetWaTemplates() {
    setState(() {
      _settings.resetTemplatesToDefault();
      _welcomeTemplateCtrl.text = _settings.templateWelcome;
      _dueTemplateCtrl.text = _settings.templateDue;
      _expiredTemplateCtrl.text = _settings.templateExpired;
      _receiptTemplateCtrl.text = _settings.templateReceipt;
    });
    _saveWaTemplates();
  }

  Future<void> _loadRealWaStatus() async {
    final st = await ApiService.instance.getRealWhatsAppStatus();
    if (mounted) {
      setState(() => _realWaStatus = st);
    }
  }

  Future<void> _loadTabletData() async {
    setState(() => _loadingTabletData = true);
    try {
      final info = await ApiService.instance.getNetworkInfo();
      final devices = await ApiService.instance.getTabletDevices();
      if (mounted) {
        setState(() {
          _networkInfo = info;
          _tabletDevices = devices;
          _loadingTabletData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTabletData = false);
    }
  }

  Future<void> _triggerTabletSync() async {
    final success = await ApiService.instance.triggerTabletSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Signal sent! All tablets are now syncing the latest member roster.' : 'Could not reach server hub.'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _openTabletInBrowser() async {
    final url = _networkInfo?['tabletUrl'] ?? 'http://localhost:5000/tablet';
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open manually in tablet browser: $url')),
        );
      }
    }
  }

  @override
  void dispose() {
    _joiningFeeController.dispose();
    _testPhoneController.dispose();
    _welcomeTemplateCtrl.dispose();
    _dueTemplateCtrl.dispose();
    _expiredTemplateCtrl.dispose();
    _receiptTemplateCtrl.dispose();
    super.dispose();
  }

  // --- Membership Plan Dialog (Add / Edit) ---
  void _openPlanDialog({MembershipPlanConfig? existingPlan, int? index}) {
    final isEditing = existingPlan != null && index != null;
    final nameCtrl = TextEditingController(text: existingPlan?.name ?? '');
    final priceCtrl = TextEditingController(text: existingPlan != null ? existingPlan.price.toInt().toString() : '10000');
    final daysCtrl = TextEditingController(text: existingPlan != null ? existingPlan.durationDays.toString() : '30');
    final descCtrl = TextEditingController(text: existingPlan?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isEditing ? Icons.edit_rounded : Icons.add_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Membership Plan' : 'Add New Membership Plan',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Plan Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Silver Plan, 3-Month Cardio',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Price (PKR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: 'Rs. ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Duration (Days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: daysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'Days',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Cardio & Strength access included',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final days = int.tryParse(daysCtrl.text.trim()) ?? 30;
              if (name.isEmpty) return;

              final plan = MembershipPlanConfig(
                id: isEditing ? existingPlan.id : name.toLowerCase().replaceAll(' ', '_'),
                name: name,
                price: price,
                durationDays: days,
                description: descCtrl.text.trim(),
              );

              setState(() {
                if (isEditing) {
                  _plans[index] = plan;
                } else {
                  _plans.add(plan);
                }
              });
              _settings.plans = List<MembershipPlanConfig>.from(_plans);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isEditing ? 'Save Plan' : 'Add Plan', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removePlan(int index) {
    if (_plans.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one membership plan must be maintained.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Membership Plan?'),
        content: Text('Are you sure you want to delete ${_plans[index].name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _plans.removeAt(index);
              });
              _settings.plans = List<MembershipPlanConfig>.from(_plans);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestWhatsApp() async {
    final phone = _testPhoneController.text.trim();
    if (phone.isEmpty) return;

    final success = await ApiService.instance.sendWhatsAppTest(phone);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1B20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: success ? AppColors.success : AppColors.warning, width: 1),
        ),
        content: Row(
          children: [
            Icon(success ? Icons.mark_chat_read_rounded : Icons.info_outline, color: success ? AppColors.success : AppColors.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success
                    ? '⚡ Test WhatsApp queued for $phone with random time delay!'
                    : 'Backend connection pending on ${_settings.backendUrl}. Check server console.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showRealWhatsAppQrDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: ApiService.instance.getRealWhatsAppQr(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final isConnected = data?['isConnected'] == true;
              final qrUrl = data?['qrCodeDataUrl'] as String?;

              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Link Real WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Open WhatsApp on your phone → Linked Devices → Link a Device → Scan this QR code:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 240,
                        height: 240,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isConnected
                            ? const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                                  SizedBox(height: 8),
                                  Text('WhatsApp Connected!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : (qrUrl != null && qrUrl.contains(','))
                                ? Image.memory(
                                    base64Decode(qrUrl.split(',')[1]),
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.contain,
                                  )
                                : const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(strokeWidth: 3),
                                      SizedBox(height: 12),
                                      Text('Generating QR Code...', style: TextStyle(color: Colors.black87, fontSize: 13)),
                                    ],
                                  ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This QR code refreshes automatically for your security.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {});
                      _loadRealWaStatus();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadRealWaStatus();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _disconnectRealWhatsApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Disconnect WhatsApp?'),
        content: const Text('Are you sure you want to disconnect this phone from the Gym System?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.instance.disconnectRealWhatsApp();
      await _loadRealWaStatus();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header matching Dashboard style (clean without the big Save button)
        Padding(
          padding: const EdgeInsets.fromLTRB(28.0, 24.0, 28.0, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings & Operations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage membership rates, tiers, and automated WhatsApp alerts',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Subtle auto-saved badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Auto-Saved',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Scrollable Single Page Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Membership Plans & Admission Fee Card
                _buildSectionCard(
                  icon: Icons.card_membership_rounded,
                  title: 'Membership Plans & Admission Fee',
                  subtitle: 'Set what you charge for new registrations and monthly gym access',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Admission Fee Toggle & Input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Charge Admission / Registration Fee',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'One-time joining fee automatically added to first-time member registrations.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _enableJoiningFee,
                                  activeTrackColor: AppColors.primary,
                                  activeThumbColor: Colors.black,
                                  onChanged: (v) {
                                    setState(() => _enableJoiningFee = v);
                                    _settings.enableJoiningFee = v;
                                  },
                                ),
                              ],
                            ),
                            if (_enableJoiningFee) ...[
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.border, height: 1),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Text(
                                    'Fee Amount:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _joiningFeeController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      decoration: const InputDecoration(
                                        prefixText: 'Rs. ',
                                        prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final fee = double.tryParse(val.replaceAll(',', ''));
                                        if (fee != null && fee >= 0) {
                                          _settings.joiningFeeAmount = fee;
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Quick amount buttons
                                  Wrap(
                                    spacing: 8,
                                    children: [3000, 5000, 7500, 10000].map((preset) {
                                      final isSelected = _joiningFeeController.text == preset.toString();
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            _joiningFeeController.text = preset.toString();
                                          });
                                          _settings.joiningFeeAmount = preset.toDouble();
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected ? AppColors.primary : AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            'Rs. ${AppSettings.formatAmount(preset)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Plans Header & Add Plan Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Membership Tiers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openPlanDialog(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add New Plan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary, width: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Plans Cards Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _plans.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.85,
                            ),
                            itemBuilder: (context, index) {
                              final plan = _plans[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            plan.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _openPlanDialog(existingPlan: plan, index: index),
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () => _removePlan(index),
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rs. ${AppSettings.formatAmount(plan.price)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${plan.durationDays} Days (${(plan.durationDays / 30).round()} Mo)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (plan.description.isNotEmpty)
                                      Text(
                                        plan.description,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else
                                      const SizedBox(height: 4),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Automated WhatsApp & Notifications Card
                _buildSectionCard(
                  icon: Icons.chat_rounded,
                  title: 'Automated WhatsApp & Customer Notifications',
                  subtitle: 'Send automated alerts to members without typing messages manually',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real WhatsApp Web Phone Linker Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: (_realWaStatus?['isConnected'] == true)
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_realWaStatus?['isConnected'] == true)
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (_realWaStatus?['isConnected'] == true)
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.warning.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                (_realWaStatus?['isConnected'] == true)
                                    ? Icons.check_circle_rounded
                                    : Icons.qr_code_scanner_rounded,
                                color: (_realWaStatus?['isConnected'] == true)
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (_realWaStatus?['isConnected'] == true)
                                        ? 'Real WhatsApp Linked: +${_realWaStatus?['connectedUser']?['phone'] ?? ''}'
                                        : 'Real WhatsApp: Waiting to Link Phone',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (_realWaStatus?['isConnected'] == true)
                                        ? 'All auto-reminders and receipts will send from your linked WhatsApp number.'
                                        : 'Scan the pairing QR code with your phone to start sending real messages.',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_realWaStatus?['isConnected'] == true)
                              OutlinedButton.icon(
                                onPressed: _disconnectRealWhatsApp,
                                icon: const Icon(Icons.link_off_rounded, size: 16),
                                label: const Text('Disconnect'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () => _showRealWhatsAppQrDialog(context),
                                icon: const Icon(Icons.qr_code_rounded, size: 16),
                                label: const Text('Link Phone (QR)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildToggleRow(
                        icon: Icons.schedule_send_rounded,
                        title: 'Send Membership Expiry Reminders',
                        description: 'Automatically alert members via WhatsApp 3 days before their plan expires and on the day of expiry.',
                        value: _sendExpiryAlert,
                        onChanged: (v) {
                          setState(() => _sendExpiryAlert = v);
                          _settings.sendExpiryAlert = v;
                        },
                      ),
                      const Divider(color: AppColors.border, height: 24),
                      _buildToggleRow(
                        icon: Icons.receipt_long_rounded,
                        title: 'Send Digital Payment Receipts',
                        description: 'Instantly dispatch a digital invoice & thank you message to member’s WhatsApp right after fee collection.',
                        value: _sendPaymentReceipt,
                        onChanged: (v) {
                          setState(() => _sendPaymentReceipt = v);
                          _settings.sendPaymentReceipt = v;
                        },
                      ),
                      const Divider(color: AppColors.border, height: 24),
                      _buildToggleRow(
                        icon: Icons.celebration_rounded,
                        title: 'Send Welcome Message & Digital Pass on Registration',
                        description: 'Send full scannable Digital Membership Pass image & welcome caption immediately upon new member enrollment.',
                        value: _sendWelcomeMessage,
                        onChanged: (v) {
                          setState(() => _sendWelcomeMessage = v);
                          _settings.sendWelcomeMessage = v;
                        },
                      ),
                      const Divider(color: AppColors.border, height: 28),

                      // Custom Message Templates Editor
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customize Automated Message Templates',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Available placeholders: {name}, {plan}, {expiry_date}, {id}, {amount}, {method}, {gym_name}',
                                style: TextStyle(fontSize: 11, color: AppColors.primary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _resetWaTemplates,
                                icon: const Icon(Icons.restore_rounded, size: 15),
                                label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _savingTemplates ? null : _saveWaTemplates,
                                icon: _savingTemplates
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Icon(Icons.save_rounded, size: 15),
                                label: Text(
                                  _savingTemplates ? 'Saving...' : 'Save Templates',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTemplateField(
                              icon: Icons.badge_rounded,
                              title: '1. Welcome & Digital Pass Caption (New Member)',
                              hint: 'Sent with the full QR Digital Membership Pass image',
                              controller: _welcomeTemplateCtrl,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildTemplateField(
                              icon: Icons.notifications_active_rounded,
                              title: '2. Upcoming Expiry / Due Reminder',
                              hint: 'Sent when membership is expiring within 5 days',
                              controller: _dueTemplateCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTemplateField(
                              icon: Icons.warning_amber_rounded,
                              title: '3. Expired Membership Alert',
                              hint: 'Sent when membership has already expired',
                              controller: _expiredTemplateCtrl,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildTemplateField(
                              icon: Icons.receipt_long_rounded,
                              title: '4. Payment / Renewal Receipt',
                              hint: 'Sent after collecting fee or renewing membership',
                              controller: _receiptTemplateCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Test WhatsApp Dispatcher
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.send_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'Test WhatsApp Notification:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: _testPhoneController,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: '+92 300 1234567',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _sendTestWhatsApp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                side: const BorderSide(color: AppColors.primary, width: 0.8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Send Test Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Tablet Kiosk & Camera Scanner Hub Card
                _buildSectionCard(
                  icon: Icons.tablet_mac_rounded,
                  title: 'Tablet Kiosk & Camera QR Scanner Hub',
                  subtitle: 'Connect entrance tablets for automated attendance check-ins with real-time offline sync',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Network Address & Direct URL Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Setup QR Code
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: (_networkInfo != null && _networkInfo!['tabletUrl'] != null)
                                  ? QrImageView(
                                      data: jsonEncode({
                                        'serverUrl': _networkInfo!['baseUrl'],
                                        'tabletUrl': _networkInfo!['tabletUrl'],
                                        'wsUrl': _networkInfo!['wsUrl'],
                                        'primaryIp': _networkInfo!['primaryIp'],
                                        'gymName': 'Titan Gym',
                                      }),
                                      version: QrVersions.auto,
                                      size: 150,
                                      backgroundColor: Colors.white,
                                    )
                                  : const SizedBox(
                                      width: 150,
                                      height: 150,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                            ),
                            const SizedBox(width: 20),

                            // Right: Setup Instructions & Launch Actions
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          'Tablet Kiosk URL: ${_networkInfo?['tabletUrl'] ?? 'http://localhost:5000/tablet'}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'How to connect any Tablet (iPad, Android, Samsung, Fire HD):',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '1. Connect your tablet and this PC to the SAME Wi-Fi or hotspot.\n'
                                    '2. On the tablet, point the camera at this QR code or open the link above in Chrome/Safari.\n'
                                    '3. Once open, tap "Fullscreen" or "Add to Home Screen" to run as a dedicated kiosk!\n'
                                    '4. New members added on this PC are instantly pushed to the tablet for offline scanning.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
                                  ),
                                  const SizedBox(height: 14),

                                  // Quick Action Buttons
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _openTabletInBrowser,
                                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                                        label: const Text('Launch Kiosk in Browser'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _triggerTabletSync,
                                        icon: const Icon(Icons.sync_rounded, size: 16),
                                        label: const Text('Push Members to Tablets Now'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary, width: 0.8),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _loadingTabletData ? null : _loadTabletData,
                                        icon: _loadingTabletData
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.refresh_rounded, size: 18),
                                        tooltip: 'Refresh connected tablets',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Connected Tablets Registry
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Connected Tablet Devices (Live Registry)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          Text(
                            '${_tabletDevices.length} Active Kiosk${_tabletDevices.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_tabletDevices.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No tablet kiosks connected yet. Open the link or scan the QR code to pair your first tablet.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tabletDevices.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final dev = _tabletDevices[idx];
                            final num? battery = dev['battery_level'] is num ? (dev['battery_level'] as num) : null;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tablet_android_rounded, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dev['device_name'] ?? 'Tablet Kiosk',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'IP: ${dev['ip_address'] ?? 'Local'} • Version: ${dev['app_version'] ?? '2.0.0'} • Total Scans: ${dev['total_scans'] ?? 0}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (battery != null) ...[
                                    Icon(
                                      battery > 20 ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                                      color: battery > 20 ? AppColors.success : AppColors.warning,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${battery.toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: battery > 20 ? AppColors.success : AppColors.warning,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ONLINE',
                                      style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Section Card Container ---
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  // --- Toggle Row Widget ---
  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: value ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          activeTrackColor: AppColors.primary,
          activeThumbColor: Colors.black,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTemplateField({
    required IconData icon,
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 12, height: 1.35),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
