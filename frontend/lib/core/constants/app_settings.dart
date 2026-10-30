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
}

class AppSettings {
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

  void resetTemplatesToDefault() {
    templateWelcome = defaultTemplateWelcome;
    templateDue = defaultTemplateDue;
    templateExpired = defaultTemplateExpired;
    templateReceipt = defaultTemplateReceipt;
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
    for (final p in plans) {
      if (p.name.toLowerCase() == clean || clean.contains(p.id)) {
        return p.price;
      }
    }
    // Fallback matches
    if (clean.contains('visitor')) return 500.0;
    if (clean.contains('silver')) return 18000.0;
    if (clean.contains('gold')) return 30000.0;
    if (clean.contains('platinum') || clean.contains('vip')) return 65000.0;
    return 8000.0;
  }

  int getPlanDurationDays(String planName) {
    final clean = planName.trim().toLowerCase();
    for (final p in plans) {
      if (p.name.toLowerCase() == clean || clean.contains(p.id)) {
        return p.durationDays;
      }
    }
    if (clean.contains('visitor')) return 1;
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
