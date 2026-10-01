import 'package:gym_system/features/members/models/member_model.dart';

class AttendanceModel {
  final MemberModel member;
  final DateTime checkInTime;

  AttendanceModel({
    required this.member,
    required this.checkInTime,
  });
}
