class TrainerModel {
  final String id;
  final String name;
  final String specialty;
  final bool isClockedIn;
  final String avatarUrl;
  final String phone;
  final int currentClients;
  final int clientCapacity;
  final String liveStatus; // "Free on Floor", "In Session (with Aisha R.)", "Off Shift"
  final String cnic;
  final String emergencyContact;
  final DateTime joinDate;
  final String shiftStart;
  final String shiftEnd;
  final double baseSalary;
  final double commissionRate;

  TrainerModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.isClockedIn,
    required this.avatarUrl,
    this.phone = '0300-1234567',
    this.currentClients = 4,
    this.clientCapacity = 8,
    this.liveStatus = 'Free on Floor',
    this.cnic = '12345-6789012-3',
    this.emergencyContact = '0300-9876543',
    DateTime? joinDate,
    this.shiftStart = '07:00 AM',
    this.shiftEnd = '03:00 PM',
    this.baseSalary = 35000,
    this.commissionRate = 0.40,
  }) : joinDate = joinDate ?? DateTime.now().subtract(const Duration(days: 365));
}
