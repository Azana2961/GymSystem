class MemberItem {
  final String id;
  final String qrToken;
  final String name;
  final String status; // 'paid', 'due', 'expired'
  final String expiryDate;
  final String? plan;
  final String? phone;

  const MemberItem({
    required this.id,
    required this.qrToken,
    required this.name,
    required this.status,
    required this.expiryDate,
    this.plan,
    this.phone,
  });

  bool get isExpired {
    if (status == 'expired') return true;
    final exp = DateTime.tryParse(expiryDate);
    if (exp != null && exp.isBefore(DateTime.now())) return true;
    return false;
  }

  bool get isDue => status == 'due';

  bool get isAccessGranted => !isExpired && !isDue;

  factory MemberItem.fromJson(Map<String, dynamic> json) {
    return MemberItem(
      id: (json['id'] ?? json['qr_token'] ?? '').toString(),
      qrToken: (json['qr_token'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Member').toString(),
      status: (json['status'] ?? 'paid').toString(),
      expiryDate: (json['expiry_date'] ?? '').toString(),
      plan: json['plan']?.toString(),
      phone: json['phone']?.toString(),
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
    };
  }
}
