class MemberModel {
  final String id;
  final String name;
  final String plan;
  final DateTime expiryDate;
  final bool isPaymentPending;

  MemberModel({
    required this.id,
    required this.name,
    required this.plan,
    required this.expiryDate,
    required this.isPaymentPending,
  });
}
