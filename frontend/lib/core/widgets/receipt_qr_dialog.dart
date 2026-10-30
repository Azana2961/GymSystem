import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/services/api_service.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptQrDialog extends StatefulWidget {
  final MemberModel member;
  final double planFee;
  final double admissionFee;
  final double discount;
  final double totalPaid;
  final String paymentMethod;
  final bool isNewRegistration;
  final String? receiptNumber;
  final DateTime? transactionTime;

  const ReceiptQrDialog({
    super.key,
    required this.member,
    required this.planFee,
    this.admissionFee = 0.0,
    this.discount = 0.0,
    required this.totalPaid,
    required this.paymentMethod,
    this.isNewRegistration = false,
    this.receiptNumber,
    this.transactionTime,
  });

  @override
  State<ReceiptQrDialog> createState() => _ReceiptQrDialogState();
}

class _ReceiptQrDialogState extends State<ReceiptQrDialog> {
  final GlobalKey _passBoundaryKey = GlobalKey();
  bool _isSendingPass = false;
  bool _hasSentPass = false;

  MemberModel get member => widget.member;
  double get planFee => widget.planFee;
  double get admissionFee => widget.admissionFee;
  double get discount => widget.discount;
  double get totalPaid => widget.totalPaid;
  String get paymentMethod => widget.paymentMethod;
  bool get isNewRegistration => widget.isNewRegistration;
  String? get receiptNumber => widget.receiptNumber;
  DateTime? get transactionTime => widget.transactionTime;

  @override
  void initState() {
    super.initState();
    // Auto-dispatch the full Pass Card image on new member registration or payment collection
    final shouldAutoSend = (isNewRegistration && AppSettings.instance.sendWelcomeMessage) ||
        (!isNewRegistration && AppSettings.instance.sendPaymentReceipt);
    if (shouldAutoSend && (member.phone?.trim().isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _sendWhatsApp(context, isAuto: true);
          }
        });
      });
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<String?> _capturePassCardBase64() async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        await WidgetsBinding.instance.endOfFrame;
        final boundary = _passBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null && !boundary.debugNeedsPaint) {
          final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            if (pngBytes.isNotEmpty) {
              return base64Encode(pngBytes);
            }
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 220));
    }
    return null;
  }

  Future<void> _sendWhatsApp(BuildContext context, {bool isAuto = false}) async {
    if (_isSendingPass) return;
    final phone = member.phone?.trim() ?? '';
    if (phone.isEmpty) {
      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number saved for this member.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSendingPass = true);

    // 1. Capture the full Digital Membership Pass Card as a high-res PNG image
    final base64PassImage = await _capturePassCardBase64();

    // 2. Send ONLY the full Pass Card image (no text caption) to Backend WhatsApp Engine
    final sentOk = await ApiService.instance.sendWhatsAppMessage(
      memberId: member.id,
      phone: phone,
      text: '',
      type: isNewRegistration ? 'welcome' : 'payment_receipt',
      imageBase64: base64PassImage,
    );

    if (!context.mounted) return;
    setState(() {
      _isSendingPass = false;
      if (sentOk) _hasSentPass = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1B1B20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: sentOk ? const Color(0xFF25D366) : AppColors.warning,
            width: 1.2,
          ),
        ),
        content: Row(
          children: [
            Icon(
              sentOk ? Icons.image_rounded : Icons.warning_amber_rounded,
              color: sentOk ? const Color(0xFF25D366) : AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sentOk
                    ? '⚡ Full Digital Pass Card Image queued for $phone via WhatsApp!'
                    : 'Could not reach backend server to send WhatsApp pass image.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyPassText(BuildContext context) {
    final text = '''
LÁ FITNESS GYM - OFFICIAL MEMBER PASS
Member: ${member.name}
ID: ${member.id}
Plan: ${member.plan}
Valid Till: ${_formatDate(member.expiryDate)}
Amount Paid: Rs. ${AppSettings.formatAmount(totalPaid)} ($paymentMethod)
QR Check-in Token: ${member.id}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Member Pass details copied to clipboard!'),
        backgroundColor: AppColors.surfaceLight,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planClean = member.plan.toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Container(
          width: 410,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F1F27),
                Color(0xFF15151A),
                Color(0xFF0F0F13),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Capturable Pass Card Area (sent as full PNG image over WhatsApp)
              RepaintBoundary(
                key: _passBoundaryKey,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1F1F27),
                        Color(0xFF15151A),
                        Color(0xFF0F0F13),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pass Header Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                        child: Row(
                          children: [
                            // Gym Logo Badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/la_fitness_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lá Fitness',
                                    style: TextStyle(
                                      fontFamily: 'SegoeScript',
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'DIGITAL MEMBERSHIP PASS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close X button
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              splashRadius: 18,
                              tooltip: 'Close Pass',
                            ),
                          ],
                        ),
                      ),

                      // Member Spotlight Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (member.isVisitor ? const Color(0xFF00E5FF) : AppColors.primary)
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (member.isVisitor ? const Color(0xFF00E5FF) : AppColors.primary)
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                member.isVisitor ? Icons.camera_alt_rounded : Icons.star_rounded,
                                                color: member.isVisitor ? const Color(0xFF00E5FF) : AppColors.primary,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                member.isVisitor ? 'VISITOR PASS' : planClean,
                                                style: TextStyle(
                                                  color: member.isVisitor ? const Color(0xFF00E5FF) : AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9.5,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: #${member.id} • ${member.phone ?? 'No Phone'}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Perforated Ticket Notches & Divider
                      const _TicketNotchDivider(),

                      const SizedBox(height: 10),

                      // Core QR Code Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.22),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              QrImageView(
                                data: member.qrToken ?? member.id,
                                version: QrVersions.auto,
                                size: 155.0,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF141418),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF141418),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F1F5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PASS KEY: ${member.qrToken ?? member.id}',
                                  style: const TextStyle(
                                    color: Color(0xFF141418),
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Text(
                        'Scan this QR code at front desk kiosk for club entry',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Pass Details Grid (Valid From, Expires On, Fee Paid)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPassStat('VALID FROM', _formatDate(member.startDate ?? DateTime.now()), false),
                              Container(width: 1, height: 28, color: AppColors.border),
                              _buildPassStat('EXPIRES ON', _formatDate(member.expiryDate), true),
                              Container(width: 1, height: 28, color: AppColors.border),
                              _buildPassStat('FEE PAID', 'Rs. ${AppSettings.formatAmount(totalPaid)}', false, subText: paymentMethod),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Section (WhatsApp Share Button & Copy)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    // Copy Details Button
                    Tooltip(
                      message: 'Copy pass details',
                      child: InkWell(
                        onTap: () => _copyPassText(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // WhatsApp Share Button (Main CTA - Sends Full Pass Card Image)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSendingPass ? null : () => _sendWhatsApp(context),
                        icon: _isSendingPass
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Icon(
                                _hasSentPass ? Icons.check_circle_rounded : Icons.image_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                        label: Text(
                          _isSendingPass
                              ? 'Sending Full Pass Image...'
                              : (_hasSentPass ? 'Pass Image Sent ✓ (Resend)' : 'Send Full Pass Image via WhatsApp'),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // Official WhatsApp Green
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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

  Widget _buildPassStat(String label, String value, bool isAccent, {String? subText}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isAccent ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        if (subText != null) ...[
          const SizedBox(height: 1),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// Authentic Ticket Pass Divider with Cutout Notches
class _TicketNotchDivider extends StatelessWidget {
  const _TicketNotchDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Perforated Dashed Line
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.maxWidth;
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) {
                  return const SizedBox(
                    width: dashWidth,
                    height: 1.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF2C2C36)),
                    ),
                  );
                }),
              );
            },
          ),
          // Left Notch Cutout
          Positioned(
            left: -12,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF0C0C0E), // Blends into modal barrier
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Right Notch Cutout
          Positioned(
            right: -12,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF0C0C0E), // Blends into modal barrier
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
