import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _employeesKey = 'hr_employees';
  static const String _leavesKey = 'hr_leaves';
  static const String _contractsKey = 'hr_contracts';
  static const String _payslipsKey = 'hr_payslips';
  static const String _attendanceKey = 'hr_attendance';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _holidayStatusTypesKey = 'holiday_status_types';
  static const String _odooUrlKey = 'odoo_url';
  static const String _odooDatabaseKey = 'odoo_database';
  static const String _isFirstLoginKey = 'is_first_login';

  // Cache duration - refresh data after 15 minutes
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Save employees data locally
  Future<void> saveEmployees(List<Map<String, dynamic>> employees) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(employees);
    await prefs.setString(_employeesKey, data);
    await _updateLastSync();
  }

  /// Get cached employees data
  Future<List<Map<String, dynamic>>?> getCachedEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_employeesKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return null;
  }

  /// Save leaves data locally
  Future<void> saveLeaves(List<Map<String, dynamic>> leaves) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(leaves);
    await prefs.setString(_leavesKey, data);
    await _updateLastSync();
  }

  /// Get cached leaves data
  Future<List<Map<String, dynamic>>?> getCachedLeaves() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_leavesKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return null;
  }

  /// Save contracts data locally
  Future<void> saveContracts(List<Map<String, dynamic>> contracts) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(contracts);
    await prefs.setString(_contractsKey, data);
    await _updateLastSync();
  }

  /// Get cached contracts data
  Future<List<Map<String, dynamic>>?> getCachedContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_contractsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return null;
  }

  /// Save payslips data locally
  Future<void> savePayslips(List<Map<String, dynamic>> payslips) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(payslips);
    await prefs.setString(_payslipsKey, data);
    await _updateLastSync();
  }

  /// Get cached payslips data
  Future<List<Map<String, dynamic>>?> getCachedPayslips() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_payslipsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return null;
  }

  /// Save attendance data locally
  Future<void> saveAttendance(List<Map<String, dynamic>> attendance) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(attendance);
    await prefs.setString(_attendanceKey, data);
    await _updateLastSync();
  }

  /// Get cached attendance data
  Future<List<Map<String, dynamic>>?> getCachedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_attendanceKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return null;
  }

  /// Save holiday status types
  Future<void> saveHolidayStatusTypes(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_holidayStatusTypesKey, jsonEncode(data));
    await prefs.setString('${_holidayStatusTypesKey}_timestamp', DateTime.now().toIso8601String());
  }

  /// Get cached holiday status types
  Future<List<Map<String, dynamic>>> getCachedHolidayStatusTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_holidayStatusTypesKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        print('❌ Error decoding cached holiday status types: $e');
        return [];
      }
    }
    return [];
  }

  /// Check if cache is valid for a specific key
  Future<bool> isCacheValid(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final timestampKey = '${key}_timestamp';
    final timestamp = prefs.getString(timestampKey);
    
    if (timestamp == null) return false;
    
    try {
      final lastSyncTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      return now.difference(lastSyncTime) < _cacheDuration;
    } catch (e) {
      print('❌ Error parsing timestamp for $key: $e');
      return false;
    }
  }

  /// Check if general cache is valid
  Future<bool> isGeneralCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey);
    if (lastSync == null) return false;
    
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final now = DateTime.now();
    return now.difference(lastSyncTime) < _cacheDuration;
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey);
    if (lastSync == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSync);
  }

  /// Update last sync timestamp
  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_employeesKey);
    await prefs.remove(_leavesKey);
    await prefs.remove(_contractsKey);
    await prefs.remove(_payslipsKey);
    await prefs.remove(_attendanceKey);
    await prefs.remove(_holidayStatusTypesKey);
    await prefs.remove(_lastSyncKey);
  }

  /// Clear specific cache
  Future<void> clearCacheFor(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'employees':
        await prefs.remove(_employeesKey);
        break;
      case 'leaves':
        await prefs.remove(_leavesKey);
        break;
      case 'contracts':
        await prefs.remove(_contractsKey);
        break;
      case 'payslips':
        await prefs.remove(_payslipsKey);
        break;
      case 'attendance':
        await prefs.remove(_attendanceKey);
        break;
      case 'holiday_status_types':
        await prefs.remove(_holidayStatusTypesKey);
        break;
    }
  }

  // Odoo Configuration Methods

  /// Save Odoo URL
  Future<void> saveOdooUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_odooUrlKey, url);
  }

  /// Get saved Odoo URL
  Future<String?> getOdooUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_odooUrlKey);
  }

  /// Save Odoo Database
  Future<void> saveOdooDatabase(String database) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_odooDatabaseKey, database);
  }

  /// Get saved Odoo Database
  Future<String?> getOdooDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_odooDatabaseKey);
  }

  /// Save Odoo configuration (URL and Database)
  Future<void> saveOdooConfig(String url, String database) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_odooUrlKey, url);
    await prefs.setString(_odooDatabaseKey, database);
  }

  /// Check if this is the first login
  Future<bool> isFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLoginKey) ?? true;
  }

  /// Set first login flag
  Future<void> setFirstLoginCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLoginKey, false);
  }

  /// Clear Odoo configuration
  Future<void> clearOdooConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_odooUrlKey);
    await prefs.remove(_odooDatabaseKey);
    await prefs.setBool(_isFirstLoginKey, true);
  }

  /// Clear all data including Odoo configuration
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
