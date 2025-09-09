class HrLeave {
  final int id;
  final String name;
  final int employeeId;
  final String? employeeName;
  final String? state;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? numberOfDays;
  final String? leaveType;
  final DateTime? createDate;
  final DateTime? writeDate;

  HrLeave({
    required this.id,
    required this.name,
    required this.employeeId,
    this.employeeName,
    this.state,
    this.dateFrom,
    this.dateTo,
    this.numberOfDays,
    this.leaveType,
    this.createDate,
    this.writeDate,
  });

  factory HrLeave.fromOdoo(Map<String, dynamic> data) {
    return HrLeave(
      id: data['id'] ?? 0,
      name: data['name'] ?? '',
      employeeId: data['employee_id']?[0] ?? 0,
      employeeName: data['employee_id']?[1],
      state: data['state'],
      dateFrom: data['date_from'] != null && data['date_from'] != false
          ? DateTime.tryParse(data['date_from'])
          : null,
      dateTo: data['date_to'] != null && data['date_to'] != false
          ? DateTime.tryParse(data['date_to'])
          : null,
      numberOfDays: data['number_of_days'] != null && data['number_of_days'] != false
          ? (data['number_of_days'] is String
              ? double.tryParse(data['number_of_days'])?.toInt()
              : data['number_of_days'] is double
                  ? data['number_of_days'].toInt()
                  : data['number_of_days'] is int
                      ? data['number_of_days']
                      : null)
          : null,
      leaveType: data['holiday_status_id']?[1],
      createDate: data['create_date'] != null
          ? DateTime.tryParse(data['create_date'])
          : null,
      writeDate: data['write_date'] != null
          ? DateTime.tryParse(data['write_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'state': state,
      'date_from': dateFrom?.toIso8601String(),
      'date_to': dateTo?.toIso8601String(),
      'number_of_days': numberOfDays,
      'leave_type': leaveType,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> toOdoo() {
    return {
      'name': name,
      'employee_id': employeeId,
      'date_from': dateFrom != null ? _formatDateTimeForOdoo(dateFrom!) : null,
      'date_to': dateTo != null ? _formatDateTimeForOdoo(dateTo!) : null,
      'holiday_status_id': _getHolidayStatusId(leaveType),
      'state': state ?? 'confirm',
      'number_of_days': numberOfDays,
    };
  }

  // Helper method to format datetime for Odoo (YYYY-MM-DD HH:MM:SS)
  String _formatDateTimeForOdoo(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
           '${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Helper method to map leave type to holiday status ID
  int _getHolidayStatusId(String? leaveType) {
    // Based on the actual Odoo data from the logs
    switch (leaveType) {
      case 'Paid Time Off':
        return 1;
      case 'Sick Time Off':
        return 2;
      case 'Compensatory Days':
        return 3;
      case 'Unpaid':
        return 4;
      case 'Parental Leaves':
        return 5;
      case 'Training Time Off':
        return 6;
      case 'Extra Hours':
        return 7;
      default:
        return 1; // Default to Paid Time Off
    }
  }

  HrLeave copyWith({
    int? id,
    String? name,
    int? employeeId,
    String? employeeName,
    String? state,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? numberOfDays,
    String? leaveType,
    DateTime? createDate,
    DateTime? writeDate,
  }) {
    return HrLeave(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      state: state ?? this.state,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      leaveType: leaveType ?? this.leaveType,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
    );
  }

  /// Get leave status display text
  String get statusDisplay {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'confirm':
        return 'Confirmed';
      case 'validate':
        return 'Validated';
      case 'refuse':
        return 'Refused';
      case 'cancel':
        return 'Cancelled';
      default:
        return state ?? 'Unknown';
    }
  }

  /// Check if leave is approved
  bool get isApproved => state == 'validate';

  /// Check if leave is pending
  bool get isPending => state == 'confirm';

  /// Check if leave is refused
  bool get isRefused => state == 'refuse';

  /// Get formatted date range
  String get dateRangeDisplay {
    if (dateFrom == null) return 'N/A';
    final start = dateFrom!.toLocal().toString().split(' ')[0];
    if (dateTo == null) return start;
    final end = dateTo!.toLocal().toString().split(' ')[0];
    return '$start to $end';
  }

  /// Get leave period (e.g., "August 2025")
  String get periodDisplay {
    if (dateFrom == null) return 'N/A';
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = months[dateFrom!.month - 1];
    final year = dateFrom!.year;
    return '$month $year';
  }
}
