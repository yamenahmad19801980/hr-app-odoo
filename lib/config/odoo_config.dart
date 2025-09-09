import '../services/local_storage_service.dart';

class OdooConfig {
  // Odoo server configuration
  // Default values - will be overridden by saved configuration
  static const String _defaultBaseUrl = 'http://localhost:8069';
  static const String _defaultDatabase = 'hr';
  static const String apiVersion = '1.0';
  
  // Dynamic configuration - will be loaded from storage
  static String _baseUrl = _defaultBaseUrl;
  static String _database = _defaultDatabase;
  
  // Getters for current configuration
  static String get baseUrl => _baseUrl;
  static String get database => _database;
  
  // API endpoints
  static const String xmlRpcEndpoint = '/xmlrpc/2/';
  static const String commonEndpoint = '/xmlrpc/2/common';
  static const String objectEndpoint = '/xmlrpc/2/object';
  
  // Authentication timeout
  static const int connectionTimeout = 30000; // 30 seconds
  static const int readTimeout = 30000; // 30 seconds
  static const int writeTimeout = 30000; // 30 seconds for write operations
  
  // Default page size for records
  static const int defaultPageSize = 20;
  
  // HR Models
  static const String hrEmployeeModel = 'hr.employee';
  static const String hrAttendanceModel = 'hr.attendance';
  static const String hrExpenseModel = 'hr.expense';
  static const String hrContractModel = 'hr.contract';
  static const String hrPayslipModel = 'hr.payslip';
  static const String hrLeaveModel = 'hr.leave';
  static const String hrExpenseCategoryModel = 'hr.expense.category';
  static const String hrWorkScheduleModel = 'hr.work.schedule';
  
  /// Get the full URL for a specific endpoint
  static String getEndpointUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  /// Get common endpoint URL
  static String get commonUrl => getEndpointUrl(commonEndpoint);
  
  /// Get object endpoint URL
  static String get objectUrl => getEndpointUrl(objectEndpoint);
  
  /// Load configuration from local storage
  static Future<void> loadConfiguration() async {
    final storage = LocalStorageService();
    final savedUrl = await storage.getOdooUrl();
    final savedDatabase = await storage.getOdooDatabase();
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
    
    if (savedDatabase != null && savedDatabase.isNotEmpty) {
      _database = savedDatabase;
    }
  }
  
  /// Update configuration and save to storage
  static Future<void> updateConfiguration(String url, String database) async {
    _baseUrl = url;
    _database = database;
    
    final storage = LocalStorageService();
    await storage.saveOdooConfig(url, database);
  }
  
  /// Reset to default configuration
  static Future<void> resetToDefault() async {
    _baseUrl = _defaultBaseUrl;
    _database = _defaultDatabase;
    
    final storage = LocalStorageService();
    await storage.clearOdooConfig();
  }
  
  /// Check if configuration is set (not default)
  static bool get isConfigured {
    return _baseUrl != _defaultBaseUrl || _database != _defaultDatabase;
  }
} 