import 'package:gym_system/features/dashboard/models/attendance_model.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';

class DummyData {
  static final List<MemberModel> members = [
    MemberModel(id: 'M001', name: 'John Doe', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 30)), isPaymentPending: false),
    MemberModel(id: 'M002', name: 'Jane Smith', plan: 'Silver Plan', expiryDate: DateTime.now().subtract(const Duration(days: 5)), isPaymentPending: true),
    MemberModel(id: 'M003', name: 'Mike Johnson', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 120)), isPaymentPending: false),
    MemberModel(id: 'M004', name: 'Emily Davis', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 15)), isPaymentPending: false),
    MemberModel(id: 'M005', name: 'Alex Brown', plan: 'Basic Plan', expiryDate: DateTime.now().subtract(const Duration(days: 2)), isPaymentPending: true),
  ];

  static final List<TrainerModel> trainers = [
    TrainerModel(id: 'T001', name: 'Chris Evans', specialty: 'Bodybuilding', isClockedIn: true, avatarUrl: 'https://i.pravatar.cc/150?u=1'),
    TrainerModel(id: 'T002', name: 'Scarlett Johansson', specialty: 'Yoga & Flexibility', isClockedIn: false, avatarUrl: 'https://i.pravatar.cc/150?u=2'),
    TrainerModel(id: 'T003', name: 'Dwayne Johnson', specialty: 'Powerlifting', isClockedIn: true, avatarUrl: 'https://i.pravatar.cc/150?u=3'),
    TrainerModel(id: 'T004', name: 'Gal Gadot', specialty: 'Cardio & HIIT', isClockedIn: true, avatarUrl: 'https://i.pravatar.cc/150?u=4'),
  ];

  static final List<AttendanceModel> recentCheckIns = [
    AttendanceModel(member: members[0], checkInTime: DateTime.now().subtract(const Duration(minutes: 5))),
    AttendanceModel(member: members[3], checkInTime: DateTime.now().subtract(const Duration(minutes: 15))),
    AttendanceModel(member: members[1], checkInTime: DateTime.now().subtract(const Duration(minutes: 20))),
    AttendanceModel(member: members[2], checkInTime: DateTime.now().subtract(const Duration(minutes: 45))),
  ];
}
