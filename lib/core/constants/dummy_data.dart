import 'package:gym_system/features/dashboard/models/attendance_model.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';

class DummyData {
  static final List<MemberModel> members = [
    MemberModel(id: 'M001', name: 'John Doe', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 30)), isPaymentPending: false, trainerId: 'T001', phone: '+1 555 0101', email: 'john.doe@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 300))),
    MemberModel(id: 'M002', name: 'Jane Smith', plan: 'Silver Plan', expiryDate: DateTime.now().subtract(const Duration(days: 5)), isPaymentPending: true, trainerId: 'T002', phone: '+1 555 0102', email: 'jane.smith@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 180))),
    MemberModel(id: 'M003', name: 'Mike Johnson', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 120)), isPaymentPending: false, trainerId: 'T003', phone: '+1 555 0103', email: 'mike.johnson@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 420))),
    MemberModel(id: 'M004', name: 'Emily Davis', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 15)), isPaymentPending: false, trainerId: 'T004', phone: '+1 555 0104', email: 'emily.davis@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 210))),
    MemberModel(id: 'M005', name: 'Alex Brown', plan: 'Basic Plan', expiryDate: DateTime.now().subtract(const Duration(days: 2)), isPaymentPending: true, trainerId: 'T005', phone: '+1 555 0105', email: 'alex.brown@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 90))),
    MemberModel(id: 'M006', name: 'Sarah Wilson', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 45)), isPaymentPending: false, trainerId: 'T001', phone: '+1 555 0106', email: 'sarah.wilson@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 260)), notes: 'Focus on compound lifts.'),
    MemberModel(id: 'M007', name: 'Daniel Moore', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 200)), isPaymentPending: false, trainerId: 'T003', phone: '+1 555 0107', email: 'daniel.moore@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 500))),
    MemberModel(id: 'M008', name: 'Olivia Taylor', plan: 'Silver Plan', expiryDate: DateTime.now().add(const Duration(days: 6)), isPaymentPending: false, trainerId: 'T002', phone: '+1 555 0108', email: 'olivia.taylor@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 150))),
    MemberModel(id: 'M009', name: 'Marcus Anderson', plan: 'Basic Plan', expiryDate: DateTime.now().add(const Duration(days: 25)), isPaymentPending: false, trainerId: 'T007', phone: '+1 555 0109', email: 'marcus.anderson@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 120))),
    MemberModel(id: 'M010', name: 'Sophia Thomas', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 60)), isPaymentPending: false, trainerId: 'T006', phone: '+1 555 0110', email: 'sophia.thomas@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 330))),
    MemberModel(id: 'M011', name: 'Liam Jackson', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 90)), isPaymentPending: false, trainerId: 'T003', phone: '+1 555 0111', email: 'liam.jackson@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 400))),
    MemberModel(id: 'M012', name: 'Aisha Rahman', plan: 'Silver Plan', expiryDate: DateTime.now().add(const Duration(days: 3)), isPaymentPending: false, trainerId: 'T006', phone: '+1 555 0112', email: 'aisha.rahman@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 200))),
    MemberModel(id: 'M013', name: 'Noah Martinez', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 75)), isPaymentPending: false, trainerId: 'T004', phone: '+1 555 0113', email: 'noah.martinez@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 280))),
    MemberModel(id: 'M014', name: 'Emma Wilson', plan: 'Basic Plan', expiryDate: DateTime.now().subtract(const Duration(days: 12)), isPaymentPending: true, trainerId: 'T005', phone: '+1 555 0114', email: 'emma.wilson@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 140))),
    MemberModel(id: 'M015', name: 'Ethan Clark', plan: 'Silver Plan', expiryDate: DateTime.now().add(const Duration(days: 40)), isPaymentPending: false, trainerId: 'T007', phone: '+1 555 0115', email: 'ethan.clark@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 230))),
    MemberModel(id: 'M016', name: 'Mia Lewis', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 55)), isPaymentPending: false, trainerId: 'T001', phone: '+1 555 0116', email: 'mia.lewis@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 310))),
    MemberModel(id: 'M017', name: 'Lucas Walker', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 150)), isPaymentPending: false, trainerId: 'T008', phone: '+1 555 0117', email: 'lucas.walker@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 460))),
    MemberModel(id: 'M018', name: 'Amelia Hall', plan: 'Silver Plan', expiryDate: DateTime.now().add(const Duration(days: 20)), isPaymentPending: false, trainerId: 'T002', phone: '+1 555 0118', email: 'amelia.hall@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 170))),
    MemberModel(id: 'M019', name: 'James Young', plan: 'Basic Plan', expiryDate: DateTime.now().add(const Duration(days: 10)), isPaymentPending: false, trainerId: 'T004', phone: '+1 555 0119', email: 'james.young@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 95))),
    MemberModel(id: 'M020', name: 'Zoe Hernandez', plan: 'Gold Plan', expiryDate: DateTime.now().add(const Duration(days: 65)), isPaymentPending: false, trainerId: 'T006', phone: '+1 555 0120', email: 'zoe.hernandez@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 340))),
    MemberModel(id: 'M021', name: 'Ryan King', plan: 'Silver Plan', expiryDate: DateTime.now().add(const Duration(days: 35)), isPaymentPending: false, trainerId: 'T008', phone: '+1 555 0121', email: 'ryan.king@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 185))),
    MemberModel(id: 'M022', name: 'Isabella Wright', plan: 'Platinum Plan', expiryDate: DateTime.now().add(const Duration(days: 110)), isPaymentPending: false, trainerId: 'T001', phone: '+1 555 0122', email: 'isabella.wright@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 380))),
    MemberModel(id: 'M023', name: 'Omar Khan', plan: 'Basic Plan', expiryDate: DateTime.now().add(const Duration(days: 18)), isPaymentPending: false, trainerId: 'T005', phone: '+1 555 0123', email: 'omar.khan@example.com', gender: 'Male', startDate: DateTime.now().subtract(const Duration(days: 110))),
    MemberModel(id: 'M024', name: 'Chloe Bennett', plan: 'Gold Plan', expiryDate: DateTime.now().subtract(const Duration(days: 8)), isPaymentPending: false, trainerId: 'T007', phone: '+1 555 0124', email: 'chloe.bennett@example.com', gender: 'Female', startDate: DateTime.now().subtract(const Duration(days: 265))),
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

  static List<MemberModel> membersForTrainer(String trainerId) =>
      members.where((m) => m.trainerId == trainerId).toList();
}