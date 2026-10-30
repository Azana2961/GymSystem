import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gym_system/core/services/api_service.dart';

class MembershipPlanConfig {
  final String id;
  final String name;
  final double price;
  final int durationDays;
  final String description;

  const MembershipPlanConfig({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    this.description = '',
  });

  MembershipPlanConfig copyWith({
    String? id,
    String? name,
    double? price,
    int? durationDays,
    String? description,
  }) {
    return MembershipPlanConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationDays: durationDays ?? this.durationDays,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'durationDays': durationDays,
        'description': description,
      };

  factory MembershipPlanConfig.fromJson(Map<String, dynamic> json) {
    return MembershipPlanConfig(
      id: json['id']?.toString() ?? 'plan',
      name: json['name']?.toString() ?? 'Plan',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0),
      durationDays: (json['durationDays'] is num)
          ? (json['durationDays'] as num).toInt()
          : (int.tryParse(json['durationDays']?.toString() ?? '30') ?? 30),
      description: json['description']?.toString() ?? '',
    );
  }
}

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  static AppSettings get instance => _instance;

  AppSettings._internal();

  // Admission / Joining Fee
  bool enableJoiningFee = true;
  double joiningFeeAmount = 5000.0;

  // Membership Plans
  List<MembershipPlanConfig> plans = [
    const MembershipPlanConfig(
      id: 'basic',
      name: 'Basic Plan',
      price: 8000.0,
      durationDays: 30,
      description: 'Standard 1 Month Gym Access',
    ),
    const MembershipPlanConfig(
      id: 'silver',
      name: 'Silver Plan',
      price: 18000.0,
      durationDays: 90,
      description: '3 Months Cardio & Strength Access',
    ),
    const MembershipPlanConfig(
      id: 'gold',
      name: 'Gold Plan',
      price: 30000.0,
      durationDays: 180,
      description: '6 Months Full Access + Locker',
    ),
    const MembershipPlanConfig(
      id: 'platinum',
      name: 'Platinum Plan',
      price: 65000.0,
      durationDays: 365,
      description: 'Annual VIP Access + All Amenities',
    ),
  ];

  // Available Payment Methods
  List<String> paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Bank Transfer',
    'JazzCash',
    'Easypaisa',
  ];

  // Automated WhatsApp Notifications
  bool sendExpiryAlert = true;
  bool sendPaymentReceipt = true;
  bool sendWelcomeMessage = true;

  // Customizable WhatsApp Message Templates
  static const String defaultTemplateWelcome =
      '{Salam|Hello|Welcome} {name}! 👋\n'
      'Thank you for joining *{gym_name}*! Your *{plan}* membership pass is active and valid until *{expiry_date}*.\n'
      'Your Member ID is *{id}*.\n'
      'Scan the attached Digital Membership Pass QR code at the front desk kiosk for entry! 💪';

  static const String defaultTemplateDue =
      '{Salam|Hello|Dear} {name}! ⚠️\n'
      'Friendly reminder from *{gym_name}*.\n'
      'Your *{plan}* membership is due for renewal on *{expiry_date}*.\n'
      'Kindly visit reception to renew and keep your gym access uninterrupted. Stay strong! 🏋️';

  static const String defaultTemplateExpired =
      '{Salam|Hello|Dear} {name}!\n'
      'Your *{plan}* membership at *{gym_name}* has *expired* as of *{expiry_date}*.\n'
      'Visit reception today to reactivate your membership pass. We hope to see you back on the gym floor soon! 💪';

  static const String defaultTemplateReceipt =
      '{Salam|Hello} {name}! 🧾\n'
      'Payment confirmed at *{gym_name}*.\n'
      'Plan: *{plan}*\n'
      'Amount Paid: *Rs. {amount}* ({method})\n'
      'Valid Until: *{expiry_date}*\n'
      'Thank you for training with us! 🔥';

  String gymName = 'Lá Fitness';
  String templateWelcome = defaultTemplateWelcome;
  String templateDue = defaultTemplateDue;
  String templateExpired = defaultTemplateExpired;
  String templateReceipt = defaultTemplateReceipt;

  void notifyChanged() {
    notifyListeners();
  }

  /// Syncs all current toggles, plans, payment methods, and templates to SQLite backend
  Future<bool> syncToServer() async {
    notifyListeners();
    try {
      return await ApiService.instance.updateWhatsAppSettings({
        'enable_joining_fee': enableJoiningFee.toString(),
        'joining_fee_amount': joiningFeeAmount.toInt().toString(),
        'plans_json': jsonEncode(plans.map((p) => p.toJson()).toList()),
        'payment_methods_json': jsonEncode(paymentMethods),
        'enable_expiry_alerts': sendExpiryAlert.toString(),
        'enable_payment_receipts': sendPaymentReceipt.toString(),
        'enable_welcome_msg': sendWelcomeMessage.toString(),
        'template_welcome': templateWelcome,
        'template_due': templateDue,
        'template_expired': templateExpired,
        'template_receipt': templateReceipt,
      });
    } catch (_) {
      return false;
    }
  }

  /// Loads persisted toggles, plans, payment methods, and templates from SQLite backend
  Future<void> loadFromServer() async {
    try {
      final s = await ApiService.instance.getWhatsAppSettings();
      if (s == null) return;

      if (s['enable_joining_fee'] != null) {
        enableJoiningFee = s['enable_joining_fee'].toString() == 'true';
      }
      if (s['joining_fee_amount'] != null) {
        final parsed = double.tryParse(s['joining_fee_amount'].toString());
        if (parsed != null && parsed >= 0) joiningFeeAmount = parsed;
      }
      if (s['plans_json'] != null && s['plans_json'].toString().isNotEmpty) {
        try {
          final decoded = jsonDecode(s['plans_json'].toString()) as List<dynamic>;
          if (decoded.isNotEmpty) {
            plans = decoded
                .map((item) =>
                    MembershipPlanConfig.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }
      if (s['payment_methods_json'] != null &&
          s['payment_methods_json'].toString().isNotEmpty) {
        try {
          final decoded =
              jsonDecode(s['payment_methods_json'].toString()) as List<dynamic>;
          final loadedMethods =
              decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (loadedMethods.isNotEmpty) {
            paymentMethods = loadedMethods;
          }
        } catch (_) {}
      }
      if (s['enable_expiry_alerts'] != null) {
        sendExpiryAlert = s['enable_expiry_alerts'].toString() == 'true';
      }
      if (s['enable_payment_receipts'] != null) {
        sendPaymentReceipt = s['enable_payment_receipts'].toString() == 'true';
      }
      if (s['enable_welcome_msg'] != null) {
        sendWelcomeMessage = s['enable_welcome_msg'].toString() == 'true';
      }
      if (s['template_welcome'] != null &&
          s['template_welcome'].toString().isNotEmpty) {
        templateWelcome = s['template_welcome'].toString();
      }
      if (s['template_due'] != null && s['template_due'].toString().isNotEmpty) {
        templateDue = s['template_due'].toString();
      }
      if (s['template_expired'] != null &&
          s['template_expired'].toString().isNotEmpty) {
        templateExpired = s['template_expired'].toString();
      }
      if (s['template_receipt'] != null &&
          s['template_receipt'].toString().isNotEmpty) {
        templateReceipt = s['template_receipt'].toString();
      }
      notifyListeners();
    } catch (_) {}
  }

  void resetTemplatesToDefault() {
    templateWelcome = defaultTemplateWelcome;
    templateDue = defaultTemplateDue;
    templateExpired = defaultTemplateExpired;
    templateReceipt = defaultTemplateReceipt;
    notifyListeners();
  }

  String renderTemplate(String template, Map<String, String> vars) {
    var out = template;
    final allVars = <String, String>{
      'gym_name': gymName,
      ...vars,
    };
    for (final entry in allVars.entries) {
      out = out.replaceAll('{${entry.key}}', entry.value);
    }
    return out;
  }

  // Security
  bool requireManagerPin = false;
  String managerPin = '1234';

  // Backend SQLite Server URL
  String backendUrl = 'http://localhost:5000';

  double getPlanPrice(String planName) {
    final clean = planName.trim().toLowerCase();
    // Visitor Pass is always FREE (Rs. 0)
    if (clean.contains('visitor') || clean.contains('guest')) return 0.0;
    for (final p in plans) {
      if (p.name.toLowerCase() == clean || clean.contains(p.id)) {
        return p.price;
      }
    }
    // Fallback matches
    if (clean.contains('silver')) return 18000.0;
    if (clean.contains('gold')) return 30000.0;
    if (clean.contains('platinum') || clean.contains('vip')) return 65000.0;
    return 8000.0;
  }

  int getPlanDurationDays(String planName) {
    final clean = planName.trim().toLowerCase();
    if (clean.contains('visitor') || clean.contains('guest')) return 1;
    for (final p in plans) {
      if (p.name.toLowerCase() == clean || clean.contains(p.id)) {
        return p.durationDays;
      }
    }
    if (clean.contains('silver')) return 90;
    if (clean.contains('gold')) return 180;
    if (clean.contains('platinum') || clean.contains('vip')) return 365;
    return 30;
  }

  static String formatAmount(num amount) {
    final parts = amount.toInt().toString().split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      buffer.write(parts[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}
