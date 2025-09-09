import 'dart:async';
import 'package:hr_app_odoo/models/hr_employee.dart';
import 'package:hr_app_odoo/models/hr_leave.dart';
import 'package:hr_app_odoo/models/hr_contract.dart';
import 'package:hr_app_odoo/models/hr_payslip.dart';
import 'package:hr_app_odoo/models/hr_attendance.dart';
import 'package:hr_app_odoo/services/odoo_rpc_service.dart';
import 'package:hr_app_odoo/services/local_storage_service.dart';

class OptimizedHrService {
  final OdooRPCService _odooService;
  final LocalStorageService _localStorage;
  
  // Cache for in-memory data
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Background sync timer
  Timer? _backgroundSyncTimer;
  
  // Stream controllers for real-time updates
  final StreamController<List<HrEmployee>> _employeesController = 
      StreamController<List<HrEmployee>>.broadcast();
  final StreamController<List<HrLeave>> _leavesController = 
      StreamController<List<HrLeave>>.broadcast();
  final StreamController<List<HrContract>> _contractsController = 
      StreamController<List<HrContract>>.broadcast();
  final StreamController<List<HrPayslip>> _payslipsController = 
      StreamController<List<HrPayslip>>.broadcast();
  final StreamController<List<HrAttendance>> _attendanceController = 
      StreamController<List<HrAttendance>>.broadcast();

  OptimizedHrService(this._odooService) : _localStorage = LocalStorageService();

  // Streams for real-time data updates
  Stream<List<HrEmployee>> get employeesStream => _employeesController.stream;
  Stream<List<HrLeave>> get leavesStream => _leavesController.stream;
  Stream<List<HrContract>> get contractsStream => _contractsController.stream;
  Stream<List<HrPayslip>> get payslipsStream => _payslipsController.stream;
  Stream<List<HrAttendance>> get attendanceStream => _attendanceController.stream;

  /// Initialize the service and start background sync
  Future<void> initialize() async {
    // Load cached data first
    await _loadCachedData();
    
    // Start background sync every 5 minutes
    _startBackgroundSync();
    
    // Perform initial sync if cache is invalid
    if (!await _localStorage.isGeneralCacheValid()) {
      await _performFullSync();
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performBackgroundSync();
    });
  }

  /// Perform background sync (only new/updated data)
  Future<void> _performBackgroundSync() async {
    try {
      print('🔄 Performing background sync...');
      
      // Get last sync time
      final lastSync = await _localStorage.getLastSyncTime();
      if (lastSync == null) return;

      // Sync only new/updated data since last sync
      await _syncNewDataSince(lastSync);
      
      print('✅ Background sync completed');
    } catch (e) {
      print('❌ Background sync failed: $e');
    }
  }

  /// Sync only new data since last sync
  Future<void> _syncNewDataSince(DateTime lastSync) async {
    // Convert to Odoo format
    final lastSyncStr = lastSync.toUtc().toIso8601String();
    
    // Sync leaves with date filter
    await _syncLeavesSince(lastSyncStr);
    
    // Sync attendance with date filter
    await _syncAttendanceSince(lastSyncStr);
    
    // Update cache timestamps
    _updateCacheTimestamp('leaves');
    _updateCacheTimestamp('attendance');
  }

  /// Load all cached data from local storage
  Future<void> _loadCachedData() async {
    try {
      // Load employees
      final cachedEmployees = await _localStorage.getCachedEmployees();
      if (cachedEmployees != null) {
        final employees = cachedEmployees.map((e) => HrEmployee.fromOdoo(e)).toList();
        _employeesController.add(employees);
      }

      // Load leaves
      final cachedLeaves = await _localStorage.getCachedLeaves();
      if (cachedLeaves != null) {
        final leaves = cachedLeaves.map((l) => HrLeave.fromOdoo(l)).toList();
        _leavesController.add(leaves);
      }

      // Load contracts
      final cachedContracts = await _localStorage.getCachedContracts();
      if (cachedContracts != null) {
        final contracts = cachedContracts.map((c) => HrContract.fromOdoo(c)).toList();
        _contractsController.add(contracts);
      }

      // Load payslips
      final cachedPayslips = await _localStorage.getCachedPayslips();
      if (cachedPayslips != null) {
        final payslips = cachedPayslips.map((p) => HrPayslip.fromOdoo(p)).toList();
        _payslipsController.add(payslips);
      }

      // Load attendance
      final cachedAttendance = await _localStorage.getCachedAttendance();
      if (cachedAttendance != null) {
        final attendance = cachedAttendance.map((a) => HrAttendance.fromOdoo(a)).toList();
        _attendanceController.add(attendance);
      }

      print('✅ Cached data loaded successfully');
    } catch (e) {
      print('❌ Error loading cached data: $e');
    }
  }

  /// Perform full sync of all data
  Future<void> _performFullSync() async {
    try {
      print('🔄 Starting full sync...');
      
      await Future.wait([
        _syncEmployees(),
        _syncLeaves(),
        _syncContracts(),
        _syncPayslips(),
        _syncAttendance(),
      ]);
      
      print('✅ Full sync completed successfully');
    } catch (e) {
      print('❌ Full sync failed: $e');
    }
  }

  /// Sync employees data
  Future<List<HrEmployee>> _syncEmployees() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.employee',
        fields: ['id', 'name', 'work_email', 'work_phone', 'job_title', 'department_id', 'work_location_id'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final employees = data.map((item) => HrEmployee.fromOdoo(item)).toList();
        
        // Cache the data
        await _localStorage.saveEmployees(data.map((item) => item as Map<String, dynamic>).toList());
        _updateCacheTimestamp('employees');
        
        // Update stream
        _employeesController.add(employees);
        
        return employees;
      }
      return [];
    } catch (e) {
      print('❌ Error syncing employees: $e');
      return [];
    }
  }

  /// Sync leaves data
  Future<List<HrLeave>> _syncLeaves() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.leave',
        fields: ['id', 'name', 'employee_id', 'holiday_status_id', 'date_from', 'date_to', 'number_of_days', 'state'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final leaves = data.map((item) => HrLeave.fromOdoo(item)).toList();
        
        // Cache the data
        await _localStorage.saveLeaves(data.map((item) => item as Map<String, dynamic>).toList());
        _updateCacheTimestamp('leaves');
        
        // Update stream
        _leavesController.add(leaves);
        
        return leaves;
      }
      return [];
    } catch (e) {
      print('❌ Error syncing leaves: $e');
      return [];
    }
  }

  /// Sync contracts data
  Future<List<HrContract>> _syncContracts() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.contract',
        fields: ['id', 'name', 'employee_id', 'date_start', 'date_end', 'state', 'wage'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final contracts = data.map((item) => HrContract.fromOdoo(item)).toList();
        
        // Cache the data
        await _localStorage.saveContracts(data.map((item) => item as Map<String, dynamic>).toList());
        _updateCacheTimestamp('contracts');
        
        // Update stream
        _contractsController.add(contracts);
        
        return contracts;
      }
      return [];
    } catch (e) {
      print('❌ Error syncing contracts: $e');
      return [];
    }
  }

  /// Sync payslips data
  Future<List<HrPayslip>> _syncPayslips() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.payslip',
        fields: ['id', 'name', 'employee_id', 'state', 'date_from', 'date_to', 'basic_wage', 'gross_wage', 'net_wage'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final payslips = data.map((item) => HrPayslip.fromOdoo(item)).toList();
        
        // Cache the data
        await _localStorage.savePayslips(data.map((item) => item as Map<String, dynamic>).toList());
        _updateCacheTimestamp('payslips');
        
        // Update stream
        _payslipsController.add(payslips);
        
        return payslips;
      }
      return [];
    } catch (e) {
      print('❌ Error syncing payslips: $e');
      return [];
    }
  }

  /// Sync attendance data
  Future<List<HrAttendance>> _syncAttendance() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.attendance',
        fields: ['id', 'employee_id', 'check_in', 'check_out', 'worked_hours'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final attendance = data.map((item) => HrAttendance.fromOdoo(item)).toList();
        
        // Cache the data
        await _localStorage.saveAttendance(data.map((item) => item as Map<String, dynamic>).toList());
        _updateCacheTimestamp('attendance');
        
        // Update stream
        _attendanceController.add(attendance);
        
        return attendance;
      }
      return [];
    } catch (e) {
      print('❌ Error syncing attendance: $e');
      return [];
    }
  }

  /// Sync leaves since a specific date
  Future<void> _syncLeavesSince(String sinceDate) async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.leave',
        fields: ['id', 'name', 'employee_id', 'holiday_status_id', 'date_from', 'date_to', 'number_of_days', 'state'],
        domain: [['write_date', '>', sinceDate]],
        limit: 50,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final leaves = data.map((item) => HrLeave.fromOdoo(item)).toList();
        
        // Update cache and stream
        await _localStorage.saveLeaves(data.map((item) => item as Map<String, dynamic>).toList());
        _leavesController.add(leaves);
      }
    } catch (e) {
      print('❌ Error syncing leaves since date: $e');
    }
  }

  /// Sync attendance since a specific date
  Future<void> _syncAttendanceSince(String sinceDate) async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.attendance',
        fields: ['id', 'employee_id', 'check_in', 'check_out', 'worked_hours'],
        domain: [['write_date', '>', sinceDate]],
        limit: 50,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        final attendance = data.map((item) => HrAttendance.fromOdoo(item)).toList();
        
        // Update cache and stream
        await _localStorage.saveAttendance(data.map((item) => item as Map<String, dynamic>).toList());
        _attendanceController.add(attendance);
      }
    } catch (e) {
      print('❌ Error syncing attendance since date: $e');
    }
  }

  /// Update cache timestamp for a specific data type
  void _updateCacheTimestamp(String dataType) {
    _cacheTimestamps[dataType] = DateTime.now();
  }

  /// Get employees (from cache or sync)
  Future<List<HrEmployee>> getEmployees() async {
    // Check if we have recent data in memory
    if (_memoryCache['employees'] != null && 
        _cacheTimestamps['employees'] != null &&
        DateTime.now().difference(_cacheTimestamps['employees']!) < const Duration(minutes: 15)) {
      return _memoryCache['employees'] as List<HrEmployee>;
    }

    // Sync fresh data
    return await _syncEmployees();
  }

  /// Get leaves (from cache or sync)
  Future<List<HrLeave>> getLeaves() async {
    // Check if we have recent data in memory
    if (_memoryCache['leaves'] != null && 
        _cacheTimestamps['leaves'] != null &&
        DateTime.now().difference(_cacheTimestamps['leaves']!) < const Duration(minutes: 15)) {
      return _memoryCache['leaves'] as List<HrLeave>;
    }

    // Sync fresh data
    return await _syncLeaves();
  }

  /// Get contracts (from cache or sync)
  Future<List<HrContract>> getContracts() async {
    // Check if we have recent data in memory
    if (_memoryCache['contracts'] != null && 
        _cacheTimestamps['contracts'] != null &&
        DateTime.now().difference(_cacheTimestamps['contracts']!) < const Duration(minutes: 15)) {
      return _memoryCache['contracts'] as List<HrContract>;
    }

    // Sync fresh data
    return await _syncContracts();
  }

  /// Get payslips (from cache or sync)
  Future<List<HrPayslip>> getPayslips() async {
    // Check if we have recent data in memory
    if (_memoryCache['payslips'] != null && 
        _cacheTimestamps['payslips'] != null &&
        DateTime.now().difference(_cacheTimestamps['payslips']!) < const Duration(minutes: 15)) {
      return _memoryCache['payslips'] as List<HrPayslip>;
    }

    // Sync fresh data
    return await _syncPayslips();
  }

  /// Get attendance (from cache or sync)
  Future<List<HrAttendance>> getAttendance() async {
    // Check if we have recent data in memory
    if (_memoryCache['attendance'] != null && 
        _cacheTimestamps['attendance'] != null &&
        DateTime.now().difference(_cacheTimestamps['attendance']!) < const Duration(minutes: 15)) {
      return _memoryCache['attendance'] as List<HrAttendance>;
    }

    // Sync fresh data
    return await _syncAttendance();
  }

  /// Get holiday status types
  Future<List<Map<String, dynamic>>> getHolidayStatusTypes() async {
    try {
      final result = await _odooService.searchRead(
        model: 'hr.leave.type',
        fields: ['id', 'name'],
        domain: [],
        limit: 100,
      );
      
      if (result['success']) {
        final data = result['data'] as List<dynamic>;
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error getting holiday status types: $e');
      return [];
    }
  }

  /// Create a new leave request
  Future<bool> createLeave(Map<String, dynamic> leaveData) async {
    try {
      final result = await _odooService.create(
        model: 'hr.leave',
        values: leaveData,
      );
      
      if (result['success']) {
        // Refresh leaves data
        await _syncLeaves();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creating leave: $e');
      return false;
    }
  }

  /// Update a leave request
  Future<bool> updateLeave(int leaveId, Map<String, dynamic> values) async {
    try {
      final result = await _odooService.write(
        model: 'hr.leave',
        recordId: leaveId,
        values: values,
      );
      
      if (result['success']) {
        // Refresh leaves data
        await _syncLeaves();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating leave: $e');
      return false;
    }
  }

  /// Force refresh all data
  Future<void> forceRefresh() async {
    try {
      print('🔄 Force refreshing all data...');
      await _performFullSync();
      print('✅ Force refresh completed');
    } catch (e) {
      print('❌ Force refresh failed: $e');
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    await _localStorage.clearCache();
    print('✅ All caches cleared');
  }

  /// Get cache age for specific data type
  Duration getCacheAge(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return const Duration(days: 1);
    return DateTime.now().difference(timestamp);
  }

  /// Dispose resources
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _employeesController.close();
    _leavesController.close();
    _contractsController.close();
    _payslipsController.close();
    _attendanceController.close();
  }
}
