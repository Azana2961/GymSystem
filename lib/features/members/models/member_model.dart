class MemberModel {
  final String id;
  final String name;
  final String plan;
  final DateTime expiryDate;
  final bool isPaymentPending;
  final String? phone;
  final String? email;
  final DateTime? startDate;
  final String? gender;
  final String? notes;
  final bool isActive;
  final String? trainerId;

  MemberModel({
    required this.id,
    required this.name,
    required this.plan,
    required this.expiryDate,
    required this.isPaymentPending,
    this.phone,
    this.email,
    this.startDate,
    this.gender,
    this.notes,
    this.isActive = true,
    this.trainerId,
  });

  MemberModel copyWith({
    String? id,
    String? name,
    String? plan,
    DateTime? expiryDate,
    bool? isPaymentPending,
    String? phone,
    String? email,
    DateTime? startDate,
    String? gender,
    String? notes,
    bool? isActive,
    String? trainerId,
  }) {
    return MemberModel(
      id: id ?? this.id,
      name: name ?? this.name,
      plan: plan ?? this.plan,
      expiryDate: expiryDate ?? this.expiryDate,
      isPaymentPending: isPaymentPending ?? this.isPaymentPending,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      startDate: startDate ?? this.startDate,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      trainerId: trainerId ?? this.trainerId,
    );
  }

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
}
