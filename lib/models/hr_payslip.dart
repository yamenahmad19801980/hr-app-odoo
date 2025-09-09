class HrPayslip {
  final int id;
  final String name;
  final int employeeId;
  final String? employeeName;
  final String? state;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final DateTime? date;
  final double? basicWage;
  final double? grossWage;
  final double? netWage;
  final DateTime? createDate;
  final DateTime? writeDate;

  HrPayslip({
    required this.id,
    required this.name,
    required this.employeeId,
    this.employeeName,
    this.state,
    this.dateFrom,
    this.dateTo,
    this.date,
    this.basicWage,
    this.grossWage,
    this.netWage,
    this.createDate,
    this.writeDate,
  });

  factory HrPayslip.fromOdoo(Map<String, dynamic> data) {
    return HrPayslip(
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
      date: data['date'] != null && data['date'] != false
          ? DateTime.tryParse(data['date'])
          : null,
      basicWage: data['basic_wage'] != null && data['basic_wage'] != false
          ? (data['basic_wage'] is String 
              ? double.tryParse(data['basic_wage']) 
              : data['basic_wage'] is double 
                  ? data['basic_wage'] 
                  : null)
          : null,
      grossWage: data['gross_wage'] != null && data['gross_wage'] != false
          ? (data['gross_wage'] is String 
              ? double.tryParse(data['gross_wage']) 
              : data['gross_wage'] is double 
                  ? data['gross_wage'] 
                  : null)
          : null,
      netWage: data['net_wage'] != null && data['net_wage'] != false
          ? (data['net_wage'] is String 
              ? double.tryParse(data['net_wage']) 
              : data['net_wage'] is double 
                  ? data['net_wage'] 
                  : null)
          : null,
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
      'date': date?.toIso8601String(),
      'basic_wage': basicWage,
      'gross_wage': grossWage,
      'net_wage': netWage,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> toOdoo() {
    return {
      'name': name,
      'employee_id': employeeId,
      'date_from': dateFrom?.toIso8601String(),
      'date_to': dateTo?.toIso8601String(),
      'date': date?.toIso8601String(),
    };
  }

  HrPayslip copyWith({
    int? id,
    String? name,
    int? employeeId,
    String? employeeName,
    String? state,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? date,
    double? basicWage,
    double? grossWage,
    double? netWage,
    DateTime? createDate,
    DateTime? writeDate,
  }) {
    return HrPayslip(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      state: state ?? this.state,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      date: date ?? this.date,
      basicWage: basicWage ?? this.basicWage,
      grossWage: grossWage ?? this.grossWage,
      netWage: netWage ?? this.netWage,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
    );
  }

  /// Get payslip status display text
  String get statusDisplay {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'verify':
        return 'Verified';
      case 'done':
        return 'Paid';
      case 'cancel':
        return 'Cancelled';
      default:
        return state ?? 'Unknown';
    }
  }

  /// Check if payslip is paid
  bool get isPaid => state == 'done';

  /// Check if payslip is verified
  bool get isVerified => state == 'verify';

  /// Check if payslip is draft
  bool get isDraft => state == 'draft';

  /// Get formatted salary display
  String get salaryDisplay {
    if (basicWage != null) {
      return '${basicWage!.toStringAsFixed(2)}';
    }
    return 'N/A';
  }

  /// Get formatted date range
  String get dateRangeDisplay {
    if (dateFrom == null) return 'N/A';
    final start = dateFrom!.toLocal().toString().split(' ')[0];
    if (dateTo == null) return start;
    final end = dateTo!.toLocal().toString().split(' ')[0];
    return '$start to $end';
  }

  /// Get payslip period (e.g., "August 2025")
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
