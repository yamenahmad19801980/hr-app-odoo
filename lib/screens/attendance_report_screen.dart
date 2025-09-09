import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hr_attendance.dart';
import '../models/hr_employee.dart';
import '../services/hr_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with TickerProviderStateMixin {
  final HrService _hrService = HrService();
  HrEmployee? _currentEmployee;
  List<HrAttendance> _allRecords = [];
  bool _isLoading = true;
  String _selectedPeriod = 'This Week';
  late AnimationController _fadeController;
  late AnimationController _slideController;

  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'Custom Range'
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentEmployee = await _hrService.getCurrentEmployee();
      if (_currentEmployee != null) {
        await _loadAttendanceRecords();
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _fadeController.forward();
      _slideController.forward();
    }
  }

  Future<void> _loadAttendanceRecords() async {
    try {
      final records = await _hrService.getEmployeeAttendance(
        employeeId: _currentEmployee!.id,
        limit: 100,
      );
      
      setState(() {
        _allRecords = records;
      });
    } catch (e) {
      print('Error loading attendance records: $e');
    }
  }

  List<HrAttendance> _getFilteredRecords() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case 'Today':
        return _allRecords.where((record) {
          final recordDate = DateTime(record.createDate.year, record.createDate.month, record.createDate.day);
          return recordDate.isAtSameMomentAs(today);
        }).toList();
        
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return _allRecords.where((record) {
          return record.createDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                 record.createDate.isBefore(endOfWeek);
        }).toList();
        
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);
        return _allRecords.where((record) {
          return record.createDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                 record.createDate.isBefore(endOfMonth);
        }).toList();
        
      case 'Last Month':
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final endOfLastMonth = DateTime(now.year, now.month, 1);
        return _allRecords.where((record) {
          return record.createDate.isAfter(startOfLastMonth.subtract(const Duration(days: 1))) &&
                 record.createDate.isBefore(endOfLastMonth);
        }).toList();
        
      default:
        return _allRecords;
    }
  }

  Map<String, dynamic> _calculateStats(List<HrAttendance> records) {
    if (records.isEmpty) {
      return {
        'total_hours': '00:00:00',
        'average_daily': '00:00:00',
        'total_sessions': 0,
        'on_time_count': 0,
        'late_count': 0,
        'early_leave_count': 0,
      };
    }

    int totalSeconds = 0;
    int totalSessions = 0;
    int onTimeCount = 0;
    int lateCount = 0;
    int earlyLeaveCount = 0;

    for (final record in records) {
      final duration = record.getWorkedDuration();
      if (duration != null) {
        totalSeconds += duration.inSeconds;
        totalSessions++;
      }

      // Simple logic for on-time/late (you can customize this)
      final checkInHour = record.checkIn.hour;
      if (checkInHour <= 9) {
        onTimeCount++;
      } else if (checkInHour <= 10) {
        lateCount++;
      } else {
        earlyLeaveCount++;
      }
    }

    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;
    final totalSecs = totalSeconds % 60;
    
    final avgSeconds = totalSessions > 0 ? totalSeconds ~/ totalSessions : 0;
    final avgHours = avgSeconds ~/ 3600;
    final avgMinutes = (avgSeconds % 3600) ~/ 60;
    final avgSecs = avgSeconds % 60;

    return {
      'total_hours': '${totalHours.toString().padLeft(2, '0')}:${totalMinutes.toString().padLeft(2, '0')}:${totalSecs.toString().padLeft(2, '0')}',
      'average_daily': '${avgHours.toString().padLeft(2, '0')}:${avgMinutes.toString().padLeft(2, '0')}:${avgSecs.toString().padLeft(2, '0')}',
      'total_sessions': totalSessions,
      'on_time_count': onTimeCount,
      'late_count': lateCount,
      'early_leave_count': earlyLeaveCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Attendance Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filteredRecords = _getFilteredRecords();
    final stats = _calculateStats(filteredRecords);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Period Selector
          _buildPeriodSelector(),
          
          const SizedBox(height: 24),
          
          // Statistics Cards
          _buildStatisticsCards(stats),
          
          const SizedBox(height: 24),
          
          // Records List
          _buildRecordsList(filteredRecords),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Select Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _periods.map((period) {
              return DropdownMenuItem(
                value: period,
                child: Text(period),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPeriod = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF764ba2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.analytics,
                color: Color(0xFF764ba2),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              icon: Icons.access_time,
              title: 'Total Hours',
              value: stats['total_hours'],
              color: const Color(0xFF667eea),
            ),
            _buildStatCard(
              icon: Icons.timer,
              title: 'Daily Average',
              value: stats['average_daily'],
              color: const Color(0xFF764ba2),
            ),
            _buildStatCard(
              icon: Icons.list_alt,
              title: 'Sessions',
              value: '${stats['total_sessions']}',
              color: const Color(0xFF48BB78),
            ),
            _buildStatCard(
              icon: Icons.check_circle,
              title: 'On Time',
              value: '${stats['on_time_count']}',
              color: const Color(0xFF38A169),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(List<HrAttendance> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.analytics,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different period',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF48BB78).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history,
                color: Color(0xFF48BB78),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Records (${records.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildRecordCard(record, index);
          },
        ),
      ],
    );
  }

  Widget _buildRecordCard(HrAttendance record, int index) {
    final isCurrentSession = record.isCheckedIn;
    final workedHours = record.getFormattedWorkedHours();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentSession ? const Color(0xFF48BB78).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentSession ? const Color(0xFF48BB78) : Colors.grey[200]!,
          width: isCurrentSession ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrentSession 
                      ? const Color(0xFF48BB78) 
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCurrentSession ? Icons.play_arrow : Icons.stop,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCurrentSession ? 'Active Session' : 'Completed Session',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCurrentSession 
                                ? const Color(0xFF48BB78) 
                                : Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        if (isCurrentSession)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF48BB78),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      DateFormat('EEEE, MMMM dd, yyyy').format(record.createDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  title: 'Check In',
                  time: DateFormat('HH:mm:ss').format(record.checkIn),
                  icon: Icons.login,
                  color: Colors.green[600]!,
                ),
              ),
              
              if (record.checkOut != null) ...[
                Expanded(
                  child: _buildTimeInfo(
                    title: 'Check Out',
                    time: DateFormat('HH:mm:ss').format(record.checkOut!),
                    icon: Icons.logout,
                    color: Colors.red[600]!,
                  ),
                ),
                
                Expanded(
                  child: _buildTimeInfo(
                    title: 'Duration',
                    time: workedHours,
                    icon: Icons.timer,
                    color: const Color(0xFF667eea),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo({
    required String title,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
