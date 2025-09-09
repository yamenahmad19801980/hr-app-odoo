class HrAttendance {
  final int id;
  final int employeeId;
  final String employeeName;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? workedHours;
  final DateTime createDate;

  HrAttendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.checkIn,
    this.checkOut,
    this.workedHours,
    required this.createDate,
  });

  factory HrAttendance.fromOdoo(Map<String, dynamic> data) {
    return HrAttendance(
      id: data['id'] ?? 0,
      employeeId: data['employee_id']?[0] ?? 0, // Odoo returns [id, name] for many2one
      employeeName: data['employee_id']?[1] ?? '',
      checkIn: DateTime.tryParse(data['check_in'] ?? '') ?? DateTime.now(),
      checkOut: data['check_out'] != null && data['check_out'] != false
          ? DateTime.tryParse(data['check_out']) 
          : null,
      workedHours: data['worked_hours'],
      createDate: DateTime.tryParse(data['create_date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'worked_hours': workedHours,
      'create_date': createDate.toIso8601String(),
    };
  }

  /// Calculate worked hours between check-in and check-out
  Duration? getWorkedDuration() {
    if (checkOut == null) return null;
    return checkOut!.difference(checkIn);
  }

  /// Format worked hours as string
  String getFormattedWorkedHours() {
    final duration = getWorkedDuration();
    if (duration == null) return '--:--:--';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if employee is currently checked in
  bool get isCheckedIn => checkOut == null;

  /// Get today's attendance records
  static List<HrAttendance> filterTodayRecords(List<HrAttendance> records) {
    final today = DateTime.now();
    return records.where((record) {
      return record.createDate.year == today.year &&
             record.createDate.month == today.month &&
             record.createDate.day == today.day;
    }).toList();
  }

  /// Calculate total worked hours for today
  static String calculateTotalWorkedHours(List<HrAttendance> todayRecords) {
    if (todayRecords.isEmpty) return '00:00:00';
    
    int totalSeconds = 0;
    for (final record in todayRecords) {
      final duration = record.getWorkedDuration();
      if (duration != null) {
        totalSeconds += duration.inSeconds;
      }
    }
    
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
} 