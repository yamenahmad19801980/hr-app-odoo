class HrEmployee {
  final int id;
  final String name;
  final String? workEmail;
  final String? workPhone;
  final String? jobTitle;
  final String? department;
  final String? workLocation;
  final String? imageUrl;
  final DateTime? hireDate;
  final String? employeeId;
  final bool isActive;

  HrEmployee({
    required this.id,
    required this.name,
    this.workEmail,
    this.workPhone,
    this.jobTitle,
    this.department,
    this.workLocation,
    this.imageUrl,
    this.hireDate,
    this.employeeId,
    this.isActive = true,
  });

  factory HrEmployee.fromOdoo(Map<String, dynamic> data) {
    return HrEmployee(
      id: data['id'] ?? 0,
      name: data['name'] ?? '',
      workEmail: data['work_email'] != false ? data['work_email'] : null,
      workPhone: data['work_phone'] != false ? data['work_phone'] : null,
      jobTitle: data['job_title'] != false ? data['job_title'] : null,
      department: data['department_id'] != false && data['department_id'] != null 
          ? data['department_id'][1] 
          : null,
      workLocation: data['work_location_id'] != false && data['work_location_id'] != null 
          ? data['work_location_id'][1] 
          : null,
      imageUrl: data['image_128'],
      hireDate: data['hire_date'] != null 
          ? DateTime.tryParse(data['hire_date']) 
          : null,
      employeeId: data['employee_id'],
      isActive: data['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'work_email': workEmail,
      'work_phone': workPhone,
      'job_title': jobTitle,
      'department': department,
      'work_location': workLocation,
      'image_url': imageUrl,
      'hire_date': hireDate?.toIso8601String(),
      'employee_id': employeeId,
      'active': isActive,
    };
  }

  HrEmployee copyWith({
    int? id,
    String? name,
    String? workEmail,
    String? workPhone,
    String? jobTitle,
    String? department,
    String? workLocation,
    String? imageUrl,
    DateTime? hireDate,
    String? employeeId,
    bool? isActive,
  }) {
    return HrEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      workEmail: workEmail ?? this.workEmail,
      workPhone: workPhone ?? this.workPhone,
      jobTitle: jobTitle ?? this.jobTitle,
      department: department ?? this.department,
      workLocation: workLocation ?? this.workLocation,
      imageUrl: imageUrl ?? this.imageUrl,
      hireDate: hireDate ?? this.hireDate,
      employeeId: employeeId ?? this.employeeId,
      isActive: isActive ?? this.isActive,
    );
  }
} 