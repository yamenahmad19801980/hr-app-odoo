import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/hr_attendance.dart';
import '../models/hr_employee.dart';
import '../services/hr_service.dart';

class AttendanceScreen extends StatefulWidget {
  final bool? initialIsCheckedIn;
  final DateTime? initialCheckInDateTime;
  final String? initialCheckInTime;
  final String? initialTotalWorkedHours;
  
  const AttendanceScreen({
    super.key,
    this.initialIsCheckedIn,
    this.initialCheckInDateTime,
    this.initialCheckInTime,
    this.initialTotalWorkedHours,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  final HrService _hrService = HrService();
  HrEmployee? _currentEmployee;
  List<HrAttendance> _todayRecords = [];
  bool _isLoading = true;
  bool _isCheckedIn = false;
  DateTime? _checkInDateTime;
  String _checkInTime = '--:--:--';
  String _totalWorkedHours = '00:00:00';
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Initialize with passed values if available
    if (widget.initialIsCheckedIn != null) {
      _isCheckedIn = widget.initialIsCheckedIn!;
    }
    if (widget.initialCheckInDateTime != null) {
      _checkInDateTime = widget.initialCheckInDateTime!;
    }
    if (widget.initialCheckInTime != null) {
      _checkInTime = widget.initialCheckInTime!;
    }
    if (widget.initialTotalWorkedHours != null) {
      _totalWorkedHours = widget.initialTotalWorkedHours!;
    }
    
    _loadAttendanceData();
    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh attendance data when screen becomes visible
    _refreshAttendanceState();
  }

  @override
  void dispose() {
    _stopTimer();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Refresh attendance state from Odoo to ensure sync with home screen
  Future<void> _refreshAttendanceState() async {
    try {
      final summary = await _hrService.getTodayAttendanceSummary();
      if (mounted) {
        setState(() {
          _isCheckedIn = summary['is_checked_in'] ?? false;
          _totalWorkedHours = summary['total_worked_hours'] ?? '00:00:00';
          
          // Set check-in time if available
          if (summary['current_check_in'] != null) {
            final checkInTime = summary['current_check_in'] as DateTime;
            _checkInDateTime = checkInTime;
            _checkInTime = '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}:${checkInTime.second.toString().padLeft(2, '0')}';
          } else {
            _checkInDateTime = null;
            _checkInTime = '--:--:--';
          }
        });
        
        // Start or stop timer based on check-in status
        if (_isCheckedIn && _checkInDateTime != null) {
          _startTimer();
          _pulseController.repeat();
        } else {
          _stopTimer();
          _pulseController.stop();
        }
        
        // Show appropriate message based on check-in status
        if (_isCheckedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ℹ️ You are already checked in since $_checkInTime. Use the Log Out button below to check out.'),
              backgroundColor: Colors.blue[600],
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error refreshing attendance state: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCheckedIn && _checkInDateTime != null) {
        final now = DateTime.now();
        final duration = now.difference(_checkInDateTime!);
        setState(() {
          _seconds = duration.inSeconds;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _seconds = 0;
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B46C1),
        ),
      ),
    );
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current employee
      _currentEmployee = await _hrService.getCurrentEmployee();
      
      if (_currentEmployee != null) {
        // Get today's attendance summary
        final summary = await _hrService.getTodayAttendanceSummary(
          employeeId: _currentEmployee!.id,
        );
        
        setState(() {
          _isCheckedIn = summary['is_checked_in'] ?? false;
          _totalWorkedHours = summary['total_worked_hours'] ?? '00:00:00';
          _todayRecords = List<HrAttendance>.from(summary['today_records'] ?? []);
          _isLoading = false;
          
          // Set check-in time if available
          if (summary['current_check_in'] != null) {
            final checkInTime = summary['current_check_in'] as DateTime;
            _checkInDateTime = checkInTime;
            _checkInTime = '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}:${checkInTime.second.toString().padLeft(2, '0')}';
          } else {
            _checkInDateTime = null;
            _checkInTime = '--:--:--';
          }
        });
        
        // Start or stop timer based on check-in status
        if (_isCheckedIn && _checkInDateTime != null) {
          _startTimer();
          _pulseController.repeat();
        } else {
          _stopTimer();
          _pulseController.stop();
        }
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckInOut() async {
    try {
      bool success;
      if (_isCheckedIn) {
        // Check out
        success = await _hrService.checkOut(employeeId: _currentEmployee?.id);
        if (success) {
          setState(() {
            _isCheckedIn = false;
            _checkInDateTime = null;
            _checkInTime = '--:--:--';
          });
          _stopTimer();
          _pulseController.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked out'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Check in
        success = await _hrService.checkIn(employeeId: _currentEmployee?.id);
        if (success) {
          final now = DateTime.now();
          setState(() {
            _isCheckedIn = true;
            _checkInDateTime = now;
            _checkInTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          });
          _startTimer();
          _pulseController.repeat();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked in'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (success) {
        await _loadAttendanceData(); // Reload data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
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
                        'Attendance Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/attendance-report'),
                      icon: const Icon(Icons.analytics, color: Colors.white),
                      tooltip: 'View Reports',
                    ),
                    IconButton(
                      onPressed: _loadAttendanceData,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status Indicator
          _buildStatusIndicator(),
          
          const SizedBox(height: 24),
          
          // Employee Info Card
          _buildEmployeeCard(),
          
          const SizedBox(height: 24),
          
          // Main Attendance Card
          _buildMainAttendanceCard(),
          
          const SizedBox(height: 24),
          
          // Today's Summary
          _buildTodaySummary(),
          
          const SizedBox(height: 24),
          
          // Today's Records
          _buildTodayRecords(),
          
          const SizedBox(height: 24),
          
          // View Reports Button
          _buildViewReportsButton(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCheckedIn ? Colors.green[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCheckedIn ? Colors.green[200]! : Colors.blue[200]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isCheckedIn ? Colors.green[100] : Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isCheckedIn ? Icons.work : Icons.schedule,
              color: _isCheckedIn ? Colors.green[700] : Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCheckedIn ? '🟢 Currently Working' : '🔵 Ready to Start',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isCheckedIn ? Colors.green[700] : Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCheckedIn 
                    ? 'You are checked in and your work session is active'
                    : 'You are not checked in. Ready to start your work session.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isCheckedIn ? Colors.green[600] : Colors.blue[600],
                  ),
                ),
                if (_isCheckedIn && _checkInTime != '--:--:--') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Started at: $_checkInTime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF6B46C1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.person,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentEmployee?.name ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (_currentEmployee?.jobTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _currentEmployee!.jobTitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'ID: ${_currentEmployee?.id ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: _isCheckedIn 
                    ? const LinearGradient(
                        colors: [Colors.green, Colors.greenAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isCheckedIn ? Icons.work : Icons.access_time,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCheckedIn ? 'Currently Working' : 'Register Attendance',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      _isCheckedIn 
                        ? 'Checked in since $_checkInTime - Use Log Out to end your shift'
                        : 'Not Checked In - Use Log In to start your shift',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isCheckedIn ? Colors.green[600] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  icon: Icons.timer,
                  title: 'Today',
                  value: _totalWorkedHours,
                  color: const Color(0xFF667eea),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStat(
                  icon: Icons.schedule,
                  title: 'Records',
                  value: '${_todayRecords.length}',
                  color: const Color(0xFF764ba2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Session Timer (only show when checked in)
          if (_isCheckedIn) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Current Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeBox('${(_seconds ~/ 3600).toString().padLeft(2, '0')}'),
                      const Text(' : ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      _buildTimeBox('${((_seconds % 3600) ~/ 60).toString().padLeft(2, '0')}'),
                      const Text(' : ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      _buildTimeBox('${(_seconds % 60).toString().padLeft(2, '0')}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Started at $_checkInTime',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Register Attendance Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isCheckedIn ? 'End Your Shift' : 'Start Your Shift',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isCheckedIn 
                  ? 'You are currently checked in. Click Log Out to end your work session.'
                  : 'You are not checked in. Click Log In to start your work session.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleCheckInOut,
                      icon: Icon(_isCheckedIn ? Icons.logout : Icons.login),
                      label: Text(_isCheckedIn ? 'Log Out' : 'Log In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCheckedIn ? Colors.red[600] : Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/attendance-report'),
                      icon: const Icon(Icons.analytics),
                      label: const Text('View Reports'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B46C1),
                        side: const BorderSide(color: Color(0xFF6B46C1)),
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
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.today,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Today's Summary",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  icon: Icons.access_time,
                  title: 'Total Worked',
                  value: _totalWorkedHours,
                  color: const Color(0xFF667eea),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStat(
                  icon: Icons.list_alt,
                  title: 'Records',
                  value: '${_todayRecords.length}',
                  color: const Color(0xFF764ba2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRecords() {
    if (_todayRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.access_time,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records for today',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check in to start tracking your time',
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
                color: const Color(0xFF764ba2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history,
                color: Color(0xFF764ba2),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Today's Records",
              style: TextStyle(
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
          itemCount: _todayRecords.length,
          itemBuilder: (context, index) {
            final record = _todayRecords[index];
            return _buildAttendanceRecordCard(record, index);
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceRecordCard(HrAttendance record, int index) {
    final isCurrentSession = record.isCheckedIn;
    
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
      child: Row(
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
                
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check In',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(record.checkIn),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 24),
                    
                    if (record.checkOut != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check Out',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm:ss').format(record.checkOut!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 24),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duration',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            record.getFormattedWorkedHours(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewReportsButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/attendance-report'),
        icon: const Icon(Icons.analytics, size: 24),
        label: const Text(
          'View Detailed Reports',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF764ba2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
