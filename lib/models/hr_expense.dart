class HrExpense {
  final int? id;
  final String description;
  final String category;
  final double total;
  final double includedTaxes;
  final int? employeeId;
  final String? employeeName;
  final String paidBy; // 'employee' or 'company'
  final DateTime expenseDate;
  final String? notes;
  final String? state; // draft, submitted, approved, refused, done
  final DateTime? createDate;
  final DateTime? writeDate;
  final String? photoPath; // Path to attached photo

  HrExpense({
    this.id,
    required this.description,
    required this.category,
    required this.total,
    required this.includedTaxes,
    this.employeeId,
    this.employeeName,
    required this.paidBy,
    required this.expenseDate,
    this.notes,
    this.state,
    this.createDate,
    this.writeDate,
    this.photoPath,
  });

  // Factory constructor to create HrExpense from Odoo data
  factory HrExpense.fromOdoo(Map<String, dynamic> data) {
    return HrExpense(
      id: data['id'],
      description: data['name'] ?? data['description'] ?? '',
      category: data['product_id'] is List && data['product_id'].length > 1 
          ? data['product_id'][1] 
          : data['category'] ?? 'Other', // product_id is [id, name]
      total: (data['total_amount'] ?? data['amount'] ?? 0.0).toDouble(),
      includedTaxes: (data['tax_amount'] ?? data['included_taxes'] ?? 0.0).toDouble(),
      employeeId: data['employee_id'] is List ? data['employee_id'][0] : data['employee_id'], // employee_id is [id, name]
      employeeName: data['employee_id'] is List ? data['employee_id'][1] : data['employee_name'] ?? '',
      paidBy: data['payment_mode'] ?? data['paid_by'] ?? 'employee',
      expenseDate: data['date'] != null 
          ? DateTime.parse(data['date']) 
          : DateTime.now(),
      notes: data['note'] ?? data['notes'] ?? '',
      state: data['state'] ?? 'draft',
      createDate: data['create_date'] != null 
          ? DateTime.parse(data['create_date']) 
          : null,
      writeDate: data['write_date'] != null 
          ? DateTime.parse(data['write_date']) 
          : null,
      photoPath: data['photo_path'] ?? data['attachment_ids']?.isNotEmpty == true ? 'attached' : null,
    );
  }

  // Convert to Map for Odoo API calls
  Map<String, dynamic> toOdoo() {
    final expenseData = {
      'name': description,
      'employee_id': employeeId,
      'date': expenseDate.toIso8601String().split('T')[0],
      'description': notes,
      'state': state ?? 'draft',
    };
    
    // Add amount field - use only the field that exists in Odoo 18
    if (total > 0) {
      // Based on the error, 'amount' doesn't exist, so let's try 'total_amount'
      expenseData['total_amount'] = total;
    }
    
    // Add tax information if available
    if (includedTaxes > 0) {
      expenseData['tax_amount'] = includedTaxes;
    }
    
    // Add category information
    if (category.isNotEmpty) {
      expenseData['product_id'] = _getProductId(category);
    }
    
    // Add photo attachment information if available
    if (photoPath != null && photoPath!.isNotEmpty) {
      expenseData['photo_path'] = photoPath;
      expenseData['has_attachment'] = true;
    }
    
    print('🔍 Expense data for Odoo: $expenseData');
    return expenseData;
  }

  // Helper method to get product ID based on category
  int? _getProductId(String category) {
    // Map categories to product IDs - you can customize these based on your Odoo setup
    final categoryMap = {
      'Transportation': 1,
      'Accommodation': 2,
      'Meals': 3,
      'Office Supplies': 4,
      'Travel': 5,
      'Other': 6,
    };
    
    final productId = categoryMap[category] ?? 6;
    print('🔍 Category: $category -> Product ID: $productId');
    return productId;
  }
  
  // Helper method to get category ID based on category name
  int? _getCategoryId(String category) {
    // Map categories to category IDs - you can customize these based on your Odoo setup
    final categoryMap = {
      'Transportation': 1,
      'Accommodation': 2,
      'Meals': 3,
      'Office Supplies': 4,
      'Travel': 5,
      'Other': 6,
    };
    
    final categoryId = categoryMap[category] ?? 6;
    print('🔍 Category: $category -> Category ID: $categoryId');
    return categoryId;
  }

  // Create a copy with updated fields
  HrExpense copyWith({
    int? id,
    String? description,
    String? category,
    double? total,
    double? includedTaxes,
    int? employeeId,
    String? employeeName,
    String? paidBy,
    DateTime? expenseDate,
    String? notes,
    String? state,
    DateTime? createDate,
    DateTime? writeDate,
  }) {
    return HrExpense(
      id: id ?? this.id,
      description: description ?? this.description,
      category: category ?? this.category,
      total: total ?? this.total,
      includedTaxes: includedTaxes ?? this.includedTaxes,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      paidBy: paidBy ?? this.paidBy,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      state: state ?? this.state,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
    );
  }

  @override
  String toString() {
    return 'HrExpense(id: $id, description: $description, category: $category, total: $total, employee: $employeeName, paidBy: $paidBy, date: $expenseDate)';
  }
}
