import 'package:gym_system/features/members/models/member_model.dart';

class AttendanceModel {
  final MemberModel member;
  final DateTime checkInTime;
  final String? statusOverride;
  final String? visitorPhotoUrl;

  AttendanceModel({
    required this.member,
    required this.checkInTime,
    this.statusOverride,
    this.visitorPhotoUrl,
  });

  /// Returns one of: 'active', 'due', 'expired', 'visitor'
  String get category {
    final s = (statusOverride ?? '').toLowerCase();
    if (s == 'visitor' || member.isVisitor) return 'visitor';
    if (s == 'expired') return 'expired';
    if (s == 'due' || member.isPaymentPending) return 'due';
    final daysToExpire = member.expiryDate.difference(DateTime.now()).inDays;
    if (daysToExpire < 0) return 'expired';
    if (daysToExpire <= 5) return 'due';
    return 'active';
  }
}
