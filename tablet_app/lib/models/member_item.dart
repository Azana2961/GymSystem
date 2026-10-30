class MemberItem {
  final String id;
  final String qrToken;
  final String name;
  final String status; // 'paid', 'due', 'expired', 'visitor'
  final String expiryDate;
  final String? plan;
  final String? phone;
  final double dueAmount;

  const MemberItem({
    required this.id,
    required this.qrToken,
    required this.name,
    required this.status,
    required this.expiryDate,
    this.plan,
    this.phone,
    this.dueAmount = 0.0,
  });

  bool get isVisitor =>
      status == 'visitor' ||
      qrToken.toUpperCase().startsWith('VIS-') ||
      (plan?.toLowerCase().contains('visitor') ?? false);

  bool get isExpired {
    if (isVisitor) return false;
    if (status == 'expired') return true;
    final exp = DateTime.tryParse(expiryDate);
    if (exp != null && exp.isBefore(DateTime.now())) return true;
    return false;
  }

  bool get isDue => !isVisitor && (status == 'due' || dueAmount > 0);

  bool get isAccessGranted => !isExpired && !isDue;

  factory MemberItem.fromJson(Map<String, dynamic> json) {
    final dueAmt = (json['due_amount'] as num?)?.toDouble() ?? 0.0;
    final rawStatus = (json['status'] ?? 'paid').toString();
    return MemberItem(
      id: (json['id'] ?? json['qr_token'] ?? '').toString(),
      qrToken: (json['qr_token'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Member').toString(),
      status: (dueAmt > 0 && rawStatus == 'paid') ? 'due' : rawStatus,
      expiryDate: (json['expiry_date'] ?? '').toString(),
      plan: json['plan']?.toString(),
      phone: json['phone']?.toString(),
      dueAmount: dueAmt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qr_token': qrToken,
      'name': name,
      'status': status,
      'expiry_date': expiryDate,
      'plan': plan,
      'phone': phone,
      'due_amount': dueAmount,
    };
  }
}
