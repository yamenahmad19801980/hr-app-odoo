class HrContract {
  final int id;
  final String name;
  final int employeeId;
  final String? employeeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? wage;
  final String? state;
  final DateTime? createDate;
  final DateTime? writeDate;

  HrContract({
    required this.id,
    required this.name,
    required this.employeeId,
    this.employeeName,
    this.startDate,
    this.endDate,
    this.wage,
    this.state,
    this.createDate,
    this.writeDate,
  });

  factory HrContract.fromOdoo(Map<String, dynamic> data) {
    return HrContract(
      id: data['id'] ?? 0,
      name: data['name'] ?? '',
      employeeId: data['employee_id']?[0] ?? 0,
      employeeName: data['employee_id']?[1],
      startDate: data['date_start'] != null && data['date_start'] != false
          ? DateTime.tryParse(data['date_start'])
          : null,
      endDate: data['date_end'] != null && data['date_end'] != false
          ? DateTime.tryParse(data['date_end'])
          : null,
      wage: data['wage']?.toDouble(),
      state: data['state'],
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
      'date_start': startDate?.toIso8601String(),
      'date_end': endDate?.toIso8601String(),
      'wage': wage,
      'state': state,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> toOdoo() {
    return {
      'name': name,
      'employee_id': employeeId,
      'date_start': startDate?.toIso8601String(),
      'date_end': endDate?.toIso8601String(),
      'wage': wage,
      'state': state,
    };
  }

  HrContract copyWith({
    int? id,
    String? name,
    int? employeeId,
    String? employeeName,
    DateTime? startDate,
    DateTime? endDate,
    double? wage,
    String? state,
    DateTime? createDate,
    DateTime? writeDate,
  }) {
    return HrContract(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      wage: wage ?? this.wage,
      state: state ?? this.state,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
    );
  }

  /// Get contract status display text
  String get statusDisplay {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'open':
        return 'Active';
      case 'close':
        return 'Closed';
      case 'cancel':
        return 'Cancelled';
      default:
        return state ?? 'Unknown';
    }
  }

  /// Check if contract is active
  bool get isActive {
    if (state != 'open') return false;
    if (startDate == null) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;
    return DateTime.now().isAfter(startDate!);
  }

  /// Get contract duration in days
  int? get durationDays {
    if (startDate == null) return null;
    final end = endDate ?? DateTime.now();
    return end.difference(startDate!).inDays;
  }

  /// Get formatted wage display
  String get wageDisplay {
    if (wage == null) return 'N/A';
    return '\$${wage!.toStringAsFixed(2)}';
  }

  /// Get formatted date range
  String get dateRangeDisplay {
    if (startDate == null) return 'N/A';
    final start = startDate!.toLocal().toString().split(' ')[0];
    if (endDate == null) return 'From $start (Ongoing)';
    final end = endDate!.toLocal().toString().split(' ')[0];
    return '$start to $end';
  }
}
