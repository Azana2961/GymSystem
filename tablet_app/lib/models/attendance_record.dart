class AttendanceRecord {
  final String qrToken;
  final String memberName;
  final String status;
  final String scannedAt;
  final String deviceId;
  final String? visitorPhoto;

  const AttendanceRecord({
    required this.qrToken,
    required this.memberName,
    required this.status,
    required this.scannedAt,
    required this.deviceId,
    this.visitorPhoto,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      qrToken: (json['qr_token'] ?? '').toString(),
      memberName: (json['member_name'] ?? 'Member').toString(),
      status: (json['status'] ?? 'paid').toString(),
      scannedAt: (json['scanned_at'] ?? DateTime.now().toIso8601String()).toString(),
      deviceId: (json['device_id'] ?? 'tablet').toString(),
      visitorPhoto: json['visitor_photo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qr_token': qrToken,
      'member_name': memberName,
      'status': status,
      'scanned_at': scannedAt,
      'device_id': deviceId,
      if (visitorPhoto != null) 'visitor_photo': visitorPhoto,
    };
  }
}
