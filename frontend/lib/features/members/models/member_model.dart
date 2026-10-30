class MemberModel {
  final String id;
  final String name;
  final String plan;
  final DateTime expiryDate;
  final bool isPaymentPending;
  final double dueAmount;
  final double paidAmount;
  final String? phone;
  final String? email;
  final DateTime? startDate;
  final String? gender;
  final String? notes;
  final bool isActive;
  final String? qrToken;

  MemberModel({
    required this.id,
    required this.name,
    required this.plan,
    required this.expiryDate,
    required this.isPaymentPending,
    this.dueAmount = 0.0,
    this.paidAmount = 0.0,
    this.phone,
    this.email,
    this.startDate,
    this.gender,
    this.notes,
    this.isActive = true,
    this.qrToken,
  });

  MemberModel copyWith({
    String? id,
    String? name,
    String? plan,
    DateTime? expiryDate,
    bool? isPaymentPending,
    double? dueAmount,
    double? paidAmount,
    String? phone,
    String? email,
    DateTime? startDate,
    String? gender,
    String? notes,
    bool? isActive,
    String? qrToken,
  }) {
    return MemberModel(
      id: id ?? this.id,
      name: name ?? this.name,
      plan: plan ?? this.plan,
      expiryDate: expiryDate ?? this.expiryDate,
      isPaymentPending: isPaymentPending ?? this.isPaymentPending,
      dueAmount: dueAmount ?? this.dueAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      startDate: startDate ?? this.startDate,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      qrToken: qrToken ?? this.qrToken,
    );
  }

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool get hasUdhaar => dueAmount > 0 || isPaymentPending;

  bool get isVisitor =>
      plan.toLowerCase().contains('visitor') ||
      (qrToken?.toUpperCase().startsWith('VIS-') ?? false) ||
      id.toUpperCase().startsWith('V');

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
}
