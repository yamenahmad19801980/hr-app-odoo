import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hr_app_odoo/models/hr_employee.dart';
import 'package:hr_app_odoo/models/hr_leave.dart';
import 'package:hr_app_odoo/services/optimized_hr_service.dart';
import 'package:hr_app_odoo/services/odoo_rpc_service.dart';
import 'package:hr_app_odoo/services/notification_service.dart';

class TeamOffScreen extends StatefulWidget {
  const TeamOffScreen({super.key});

  @override
  State<TeamOffScreen> createState() => _TeamOffScreenState();
}

class _TeamOffScreenState extends State<TeamOffScreen> with TickerProviderStateMixin {
  late OptimizedHrService _hrService;
  late TabController _tabController;
  late NotificationService _notificationService;
  
  List<HrEmployee> _allEmployees = [];
  List<HrLeave> _allLeaves = [];
  List<HrLeave> _myLeaves = [];
  Map<String, dynamic> _leaveStats = {};
  List<Map<String, dynamic>> _holidayStatusTypes = [];
  
  // Form controllers
  final TextEditingController _leaveTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLeaveType = 'Paid Time Off';
  
  // Notification tracking
  List<HrLeave> _statusChangeNotifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hrService = OptimizedHrService(OdooRPCService.instance);
    _notificationService = NotificationService();
    
    _initializeService();
    
    // Listen to status changes
    _notificationService.statusChangeStream.listen((leave) {
      setState(() {
        if (!_statusChangeNotifications.any((n) => n.id == leave.id)) {
          _statusChangeNotifications.add(leave);
        }
      });
      
      // Show snackbar notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${leave.leaveType ?? 'Leave'} request status updated to ${leave.statusDisplay}'),
          backgroundColor: Colors.blue[600],
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Scroll to the notification
              // This could be enhanced with a scroll controller
            },
          ),
        ),
      );
    });
    
    // Start periodic status check timer (every 30 seconds)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkStatusChanges();
    });
  }

  Future<void> _initializeService() async {
    try {
      // Initialize the optimized service
      await _hrService.initialize();
      
      // Listen to data streams for real-time updates
      _hrService.employeesStream.listen((employees) {
        setState(() {
          _allEmployees = employees;
        });
      });

      _hrService.leavesStream.listen((leaves) {
        setState(() {
          _allLeaves = leaves;
        });
        _updateLeaveStatistics();
      });

      // Load initial data
      await _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize service: $e';
        _isLoading = false;
      });
      print('❌ Error initializing service: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load data in parallel
      final results = await Future.wait([
        _hrService.getEmployees(),
        _hrService.getLeaves(),
        _hrService.getHolidayStatusTypes(),
      ]);

      setState(() {
        _allEmployees = results[0] as List<HrEmployee>;
        _allLeaves = results[1] as List<HrLeave>;
        _holidayStatusTypes = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });

      // Initialize notification service with current leaves
      _notificationService.initializeWithLeaves(_allLeaves);
      
      // Check for status changes
      _notificationService.checkStatusChanges(_allLeaves);
      
      // Filter leaves for current employee (assuming first employee for now)
      if (_allEmployees.isNotEmpty) {
        final currentEmployeeId = _currentEmployeeId;
        if (currentEmployeeId != null) {
          _myLeaves = _allLeaves.where((leave) => leave.employeeId == currentEmployeeId).toList();
        }
      }
      
      _updateLeaveStatistics();

      print('✅ Data loaded successfully');
      print('✅ Team members: ${_allEmployees.length}');
      print('✅ Leaves: ${_allLeaves.length}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
      print('❌ Error loading data: $e');
    }
  }

  void _updateLeaveStatistics() {
    final total = _allLeaves.length;
    final approved = _allLeaves.where((l) => l.isApproved).length;
    final pending = _allLeaves.where((l) => l.isPending).length;
    final refused = _allLeaves.where((l) => l.isRefused).length;

    setState(() {
      _leaveStats = {
        'total': total,
        'approved': approved,
        'pending': pending,
        'refused': refused,
      };
    });
  }

  /// Clear a specific notification
  void _clearNotification(int leaveId) {
    setState(() {
      _statusChangeNotifications.removeWhere((n) => n.id == leaveId);
    });
  }

  /// Clear all notifications
  void _clearAllNotifications() {
    setState(() {
      _statusChangeNotifications.clear();
    });
  }

  /// Get current employee ID (in a real app, this would come from user authentication)
  int? get _currentEmployeeId {
    return _allEmployees.isNotEmpty ? _allEmployees.first.id : null;
  }

  /// Check for status changes in background
  void _checkStatusChanges() {
    if (_allLeaves.isNotEmpty) {
      print('🔍 Checking for status changes in ${_allLeaves.length} leaves...');
      _notificationService.checkStatusChanges(_allLeaves);
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status changes checked'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No leaves available to check'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Refresh data and check for status changes
  Future<void> _refreshData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _hrService.forceRefresh();
      await _loadData();
      
      // Check for status changes after refresh
      _checkStatusChanges();
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed and status changes checked'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Simulate status change for testing (remove in production)
  void _simulateStatusChange() {
    if (_allLeaves.isNotEmpty) {
      final leave = _allLeaves.first;
      final newLeave = leave.copyWith(state: 'approve');
      
      setState(() {
        _allLeaves[_allLeaves.indexOf(leave)] = newLeave;
        // Update my leaves if this is the current employee's leave
        if (_myLeaves.any((l) => l.id == leave.id)) {
          final index = _myLeaves.indexWhere((l) => l.id == leave.id);
          if (index != -1) {
            _myLeaves[index] = newLeave;
          }
        }
      });
      
      // Trigger notification by calling the notification service
      _notificationService.checkStatusChanges(_allLeaves);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status change simulated! Check notifications above.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leaveTypeController.dispose();
    _descriptionController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Off'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'My Time'),
            Tab(text: 'Team View'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _errorMessage!.isNotEmpty
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardView(),
                    _buildMyTimeView(),
                    _buildTeamView(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkStatusChanges,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.notifications_active, color: Colors.white),
        tooltip: 'Check for status changes',
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[600]),
          const SizedBox(height: 16),
          const Text(
            'Error loading data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status change notifications
            if (_statusChangeNotifications.isNotEmpty) ...[
              _buildStatusChangeNotifications(),
              const SizedBox(height: 16),
            ],
            _buildLeaveRequestForm(),
            const SizedBox(height: 20),
            _buildMyLeaveRequests(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChangeNotifications() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Updates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_statusChangeNotifications.isNotEmpty)
                      TextButton(
                        onPressed: _clearAllNotifications,
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    // Test button (remove in production)
                    IconButton(
                      onPressed: _simulateStatusChange,
                      icon: Icon(Icons.bug_report, size: 16, color: Colors.orange[600]),
                      tooltip: 'Test notification (dev only)',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._statusChangeNotifications.map((leave) {
              Color statusColor;
              String statusText;
              switch (leave.state) {
                case 'validate':
                  statusColor = Colors.green[600]!;
                  statusText = 'Approved';
                  break;
                case 'confirm':
                  statusColor = Colors.orange[600]!;
                  statusText = 'Pending';
                  break;
                case 'refuse':
                  statusColor = Colors.red[600]!;
                  statusText = 'Refused';
                  break;
                default:
                  statusColor = Colors.grey[600]!;
                  statusText = leave.state ?? 'Unknown';
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leave.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                leave.dateRangeDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${leave.numberOfDays ?? 0} days',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                      onPressed: () => _clearNotification(leave.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'New Leave Request',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Date conflict warning
            if (_startDate != null && _endDate != null && _hasDateConflict())
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Potential date conflict detected. Check existing leave requests below.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Form fields
            _buildFormField(
              label: 'Leave Type',
              value: _selectedLeaveType.isNotEmpty ? _selectedLeaveType : 'Select leave type',
              isReadOnly: true,
              onTap: _showLeaveTypePicker,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Start Date',
                    value: _startDate != null ? _formatDate(_startDate!) : 'Select start date',
                    isReadOnly: true,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    label: 'End Date',
                    value: _endDate != null ? _formatDate(_endDate!) : 'Select end date',
                    isReadOnly: true,
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildFormField(
              label: 'Duration',
              value: _startDate != null && _endDate != null 
                ? '${_calculateDuration()} day(s)' 
                : 'Select dates first',
              isReadOnly: true,
            ),
            const SizedBox(height: 16),
            
            _buildFormField(
              label: 'Description',
              value: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Enter description (optional)',
              isTextField: true,
              controller: _descriptionController,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canSubmitForm() ? _submitLeaveRequest : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Form'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String value,
    bool isReadOnly = false,
    bool isTextField = false,
    TextEditingController? controller,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: isTextField
          ? TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter description...',
                hintStyle: TextStyle(color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
            )
          : Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value.contains('Select') || value.contains('Enter') 
                           ? Colors.grey[600] 
                           : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!isReadOnly && onTap != null)
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
    );
  }

  Widget _buildMyLeaveRequests() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'My Leave Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_myLeaves.length} request(s)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Calendar view for existing leaves
            if (_myLeaves.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📅 Existing Leave Dates (Avoid these dates for new requests):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _myLeaves
                          .where((leave) => leave.state != 'refuse' && leave.state != 'cancel')
                          .map((leave) => _buildDateChip(leave))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // List of leave requests
            if (_myLeaves.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No leave requests yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first leave request above',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myLeaves.length,
                itemBuilder: (context, index) {
                  final leave = _myLeaves[index];
                  return _buildLeaveRequestCard(leave);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build a date chip showing existing leave dates
  Widget _buildDateChip(HrLeave leave) {
    Color chipColor;
    IconData chipIcon;
    
    switch (leave.state) {
      case 'confirm':
        chipColor = Colors.orange;
        chipIcon = Icons.schedule;
        break;
      case 'validate':
        chipColor = Colors.blue;
        chipIcon = Icons.check_circle;
        break;
      case 'approve':
        chipColor = Colors.green;
        chipIcon = Icons.verified;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 16, color: chipColor),
          const SizedBox(width: 4),
          Text(
            '${_formatDate(leave.dateFrom!)} - ${_formatDate(leave.dateTo!)}',
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(HrLeave leave) {
    Color statusColor;
    String statusText;
    
    switch (leave.state) {
      case 'validate':
        statusColor = Colors.green[600]!;
        statusText = 'Approved';
        break;
      case 'confirm':
        statusColor = Colors.orange[600]!;
        statusText = 'Pending';
        break;
      case 'refuse':
        statusColor = Colors.red[600]!;
        statusText = 'Refused';
        break;
      default:
        statusColor = Colors.grey[600]!;
        statusText = leave.state ?? 'Unknown';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leave.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        leave.dateRangeDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${leave.numberOfDays ?? 0} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendAndHolidays() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildLegendCard(),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _buildHolidaysCard(),
        ),
      ],
    );
  }

  Widget _buildLegendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Off Types',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem('Paid Time Off', true, Colors.blue[600]!),
            _buildLegendItem('Compensatory', true, Colors.green[600]!),
            _buildLegendItem('Sick Time Off', true, Colors.red[600]!),
            const SizedBox(height: 12),
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem('Approved', false, Colors.green[600]!),
            _buildLegendItem('Pending', false, Colors.orange[600]!),
            _buildLegendItem('To Approve', false, Colors.blue[600]!, isStriped: true),
            _buildLegendItem('Refused', false, Colors.red[600]!),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, bool isCheckbox, Color color, {bool isStriped = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (isCheckbox)
            Icon(Icons.check_box, color: color, size: 16)
          else
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isStriped ? Colors.white : color,
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: isStriped
                  ? CustomPaint(
                      painter: StripedPainter(color: color),
                    )
                  : null,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label, 
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Public Holidays',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildHolidayItem('July 4', 'Independence Day', Colors.blue[600]!),
            _buildHolidayItem('Nov 11', 'Veterans Day', Colors.blue[600]!),
            _buildHolidayItem('Dec 25', 'Christmas', Colors.red[600]!),
            _buildHolidayItem('Jan 1', 'New Year', Colors.red[600]!),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayItem(String date, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 10,
            ),
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 9),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMyTimeView() {
    final currentEmployee = _allEmployees.isNotEmpty ? _allEmployees.first : null;
    if (currentEmployee == null) {
      return const Center(child: Text('No employee data available'));
    }

    final myLeaves = _allLeaves.where((leave) => leave.employeeId == currentEmployee.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'My Time Off',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myLeaves.length,
            itemBuilder: (context, index) {
              final leave = myLeaves[index];
              return _buildLeaveRequestCard(leave);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allEmployees.length,
        itemBuilder: (context, index) {
          final member = _allEmployees[index];
          final memberLeaves = _allLeaves
              .where((leave) => leave.employeeId == member.id)
              .toList();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                member.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.jobTitle != null)
                    Text(member.jobTitle!),
                  if (member.department != null)
                    Text('${member.department}'),
                  Text('${memberLeaves.length} leave requests'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => _showMemberDetails(member, memberLeaves),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberDetails(HrEmployee member, List<HrLeave> memberLeaves) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.jobTitle != null)
                        Text(member.jobTitle!),
                      if (member.department != null)
                        Text('${member.department}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Leave Requests (${memberLeaves.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: memberLeaves.isEmpty
                  ? const Center(
                      child: Text('No leave requests found'),
                    )
                  : ListView.builder(
                      itemCount: memberLeaves.length,
                      itemBuilder: (context, index) {
                        final leave = memberLeaves[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(leave.state),
                              child: Icon(
                                _getStatusIcon(leave.state),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              leave.name.isNotEmpty ? leave.name : 'Leave Request',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Period: ${leave.dateRangeDisplay}'),
                                Text('Status: ${leave.statusDisplay}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateLeaveDialog() {
    final currentEmployee = _allEmployees.isNotEmpty ? _allEmployees.first : null;
    if (currentEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Leave Request'),
        content: const Text('This feature is now available in the main form above.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditLeaveDialog(HrLeave leave) {
    final nameController = TextEditingController(text: leave.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Leave Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Request Name',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedLeave = leave.copyWith(
                name: nameController.text,
              );

              final success = await _hrService.updateLeave(updatedLeave.id, updatedLeave.toOdoo());
              if (success) {
                Navigator.of(context).pop();
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Leave request updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update leave request'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? state) {
    switch (state) {
      case 'validate':
        return Colors.green;
      case 'confirm':
        return Colors.orange;
      case 'refuse':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String? state) {
    switch (state) {
      case 'validate':
        return Icons.check_circle;
      case 'confirm':
        return Icons.schedule;
      case 'refuse':
        return Icons.cancel;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  // Form helper methods
  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDuration(int days) {
    return '$days days';
  }

  int _calculateDuration() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date first')),
      );
      return;
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _showLeaveTypePicker() {
    if (_holidayStatusTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leave types available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Leave Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _holidayStatusTypes.map((type) => ListTile(
            title: Text(type['name'] ?? 'Unknown'),
            leading: Radio<String>(
              value: type['name'] ?? 'Unknown',
              groupValue: _selectedLeaveType,
              onChanged: (value) {
                setState(() {
                  _selectedLeaveType = value!;
                });
                Navigator.pop(context);
              },
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedLeaveType = _holidayStatusTypes.isNotEmpty 
          ? _holidayStatusTypes.first['name'] ?? 'Paid Time Off'
          : 'Paid Time Off';
      _descriptionController.clear();
    });
  }

  void _submitLeaveRequest() {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description')),
      );
      return;
    }

    // Create the leave request
    final newLeave = HrLeave(
      id: 0, // Will be assigned by Odoo
      name: _descriptionController.text.trim(),
      employeeId: 1, // Current employee ID
      state: 'confirm', // Pending approval
      dateFrom: _startDate,
      dateTo: _endDate,
      numberOfDays: _endDate!.difference(_startDate!).inDays + 1,
      leaveType: _selectedLeaveType,
      createDate: DateTime.now(),
      writeDate: DateTime.now(),
    );

    // Submit to Odoo
    _createLeaveRequest();
  }

  /// Create leave request
  Future<void> _createLeaveRequest() async {
    try {
      // Validate form
      if (_startDate == null || _endDate == null || _selectedLeaveType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please fill in all required fields'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check if end date is after start date
      if (_endDate!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ End date must be after start date'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check for date overlaps with existing leaves
      final hasOverlap = _allLeaves.any((leave) {
        if (leave.employeeId == _currentEmployeeId && leave.state != 'refuse' && leave.state != 'cancel') {
          final existingStart = leave.dateFrom;
          final existingEnd = leave.dateTo;
          
          if (existingStart != null && existingEnd != null) {
            // Check if the new request overlaps with existing approved/pending leave
            return (_startDate!.isBefore(existingEnd) && _endDate!.isAfter(existingStart));
          }
        }
        return false;
      });

      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ You already have approved or pending time off for this period. Please choose different dates.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Creating leave request...'),
              ],
            ),
          );
        },
      );

      // Create the leave request
      final leave = HrLeave(
        id: 0, // Will be assigned by Odoo
        name: '${_selectedLeaveType} Request',
        employeeId: _currentEmployeeId ?? 1, // Default to 1 if null
        employeeName: _allEmployees.firstWhere((e) => e.id == (_currentEmployeeId ?? 1)).name,
        state: 'confirm',
        dateFrom: _startDate,
        dateTo: _endDate,
        numberOfDays: _calculateDuration(),
        leaveType: _selectedLeaveType,
        createDate: DateTime.now(),
        writeDate: DateTime.now(),
      );

      final success = await _hrService.createLeave(leave.toOdoo());

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Clear form and show success message
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Leave request created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh data
        await _loadData();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to create leave request. Please check the dates and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show detailed error message
      String errorMessage = '❌ Error creating leave request';
      
      if (e.toString().contains('overlaps')) {
        errorMessage = '❌ Date overlap detected. Another employee already has approved time off for this period.';
      } else if (e.toString().contains('ValidationError')) {
        errorMessage = '❌ Validation error. Please check your dates and leave type selection.';
      } else if (e.toString().contains('permission')) {
        errorMessage = '❌ Permission denied. You may not have rights to create leave requests.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Help',
            textColor: Colors.white,
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ),
      );
    }
  }

  /// Show help dialog for common issues
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Request Help'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Common issues and solutions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('• Date overlap: Choose different dates if someone else has approved time off'),
                SizedBox(height: 8),
                Text('• Invalid dates: Ensure end date is after start date'),
                SizedBox(height: 8),
                Text('• Missing fields: Fill in all required information'),
                SizedBox(height: 8),
                Text('• Permission: Contact your manager if you cannot create requests'),
                SizedBox(height: 16),
                Text(
                  'Tip: Check the existing leave requests below to see what dates are already taken.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Check if there's a potential date conflict
  bool _hasDateConflict() {
    if (_startDate == null || _endDate == null) return false;
    
    return _allLeaves.any((leave) {
      if (leave.employeeId == _currentEmployeeId && leave.state != 'refuse' && leave.state != 'cancel') {
        final existingStart = leave.dateFrom;
        final existingEnd = leave.dateTo;
        
        if (existingStart != null && existingEnd != null) {
          return (_startDate!.isBefore(existingEnd) && _endDate!.isAfter(existingStart));
        }
      }
      return false;
    });
  }

  /// Check if form can be submitted
  bool _canSubmitForm() {
    return _startDate != null && 
           _endDate != null && 
           _selectedLeaveType.isNotEmpty && 
           !_endDate!.isBefore(_startDate!) &&
           !_hasDateConflict();
  }
}

// Custom painter for striped legend items
class StripedPainter extends CustomPainter {
  final Color color;
  
  StripedPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    
    for (int i = 0; i < size.width; i += 4) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
