import 'package:flutter/material.dart';
import 'dart:async';
import '../services/hr_service.dart';
import '../services/odoo_rpc_service.dart';
import '../services/local_storage_service.dart';
import '../models/hr_employee.dart';
import '../models/hr_attendance.dart';
import '../models/hr_expense.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;
  int _seconds = 0;
  bool _isCheckedIn = false;
  String _checkInTime = "--:--:--";
  String _checkOutTime = "--:--:--";
  String _totalToday = "00:00:00";
  String _beforeTime = "00:00";
  DateTime? _checkInDateTime;
  
  final HrService _hrService = HrService();
  final OdooRPCService _odooService = OdooRPCService.instance;
  HrEmployee? _currentEmployee;
  List<HrAttendance> _todayAttendance = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEmployeeData();
    _loadTodayAttendance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh attendance data when app becomes visible
      _loadTodayAttendance();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isCheckedIn && _checkInDateTime != null) {
        setState(() {
          final now = DateTime.now();
          final duration = now.difference(_checkInDateTime!);
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

  /// Load current employee data from Odoo
  Future<void> _loadEmployeeData() async {
    try {
      final employee = await _hrService.getCurrentEmployee();
      if (mounted) {
        setState(() {
          _currentEmployee = employee;
        });
      }
    } catch (e) {
      print('Error loading employee data: $e');
    }
  }

  /// Load today's attendance data from Odoo
  Future<void> _loadTodayAttendance() async {
    try {
      final summary = await _hrService.getTodayAttendanceSummary();
      if (mounted) {
        setState(() {
          _totalToday = summary['total_worked_hours'] ?? '00:00:00';
          _isCheckedIn = summary['is_checked_in'] ?? false;
          _todayAttendance = summary['today_records'] ?? [];
          
          // Set check-in time if available
          if (summary['current_check_in'] != null) {
            final checkInTime = summary['current_check_in'] as DateTime;
            _checkInDateTime = checkInTime;
            _checkInTime = '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}:${checkInTime.second.toString().padLeft(2, '0')}';
          } else {
            _checkInDateTime = null;
          }
        });
        
        // Start or stop timer based on check-in status
        if (_isCheckedIn && _checkInDateTime != null) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
    } catch (e) {
      print('Error loading attendance data: $e');
    }
  }

  /// Get appropriate greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    final weekday = now.weekday;
    
    String timeGreeting;
    if (hour >= 5 && hour < 12) {
      timeGreeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeGreeting = 'Good Evening';
    } else {
      timeGreeting = 'Good Night';
    }
    
    // Add day of the week for more personal touch
    String dayName;
    switch (weekday) {
      case 1:
        dayName = 'Monday';
        break;
      case 2:
        dayName = 'Tuesday';
        break;
      case 3:
        dayName = 'Wednesday';
        break;
      case 4:
        dayName = 'Thursday';
        break;
      case 5:
        dayName = 'Friday';
        break;
      case 6:
        dayName = 'Saturday';
        break;
      case 7:
        dayName = 'Sunday';
        break;
      default:
        dayName = '';
    }
    
    return '$timeGreeting! Happy $dayName';
  }

  /// Get current time as formatted string
  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }



  /// Handle logout
  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (shouldLogout == true) {
        // Clear all data
        final storage = LocalStorageService();
        await storage.clearAllData();
        
        // Clear Odoo service state
        _odooService.logout();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logged out successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to login screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle check in/out with Odoo
  Future<void> _handleCheckInOut() async {
    try {
      bool success;
      if (_isCheckedIn) {
        // Check out
        success = await _hrService.checkOut();
        if (success) {
          setState(() {
            _isCheckedIn = false;
            _checkOutTime = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
            _checkInDateTime = null;
          });
          _stopTimer();
          // Reload attendance data
          _loadTodayAttendance();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked out'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Check in
        success = await _hrService.checkIn();
        if (success) {
          final now = DateTime.now();
          setState(() {
            _isCheckedIn = true;
            _checkInDateTime = now;
            _checkInTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
            _checkOutTime = '--:--:--';
            _seconds = 0;
          });
          _startTimer();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked in'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update attendance. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // User info and logout button
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'user',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentEmployee?.name ?? 'Employee',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      _currentEmployee?.workEmail ?? 'No email',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Text(
                      (_currentEmployee?.name ?? 'E').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF6B46C1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Greeting Section
              Row(
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
                          '${_getGreeting()}, ${_currentEmployee?.name ?? 'Employee'}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back to your HR dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current time: ${_getCurrentTime()}',
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

              const SizedBox(height: 24),

              // Attendance Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    // Header with navigation
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Register Attendance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              Text(
                                _isCheckedIn ? 'Currently Working' : 'Not Checked In',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _isCheckedIn ? Colors.green[600] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pushNamed(
                            context, 
                            '/attendance',
                            arguments: {
                              'isCheckedIn': _isCheckedIn,
                              'checkInDateTime': _checkInDateTime,
                              'checkInTime': _checkInTime,
                              'totalWorkedHours': _totalToday,
                            },
                          ),
                          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF6B46C1)),
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
                            value: _totalToday,
                            color: const Color(0xFF667eea),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickStat(
                            icon: Icons.schedule,
                            title: 'This Week',
                            value: _beforeTime, // Reusing for weekly hours
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
                        const Text(
                          'Register Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/face-attendance'),
                            icon: Icon(_isCheckedIn ? Icons.logout : Icons.login),
                            label: Text(_isCheckedIn ? 'Check Out (Face)' : 'Check In (Face)'),
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
                            onPressed: () => Navigator.pushNamed(
                              context, 
                              '/attendance',
                              arguments: {
                                'isCheckedIn': _isCheckedIn,
                                'checkInDateTime': _checkInDateTime,
                                'checkInTime': _checkInTime,
                                'totalWorkedHours': _totalToday,
                              },
                            ),
                            icon: const Icon(Icons.visibility),
                            label: const Text('View Details'),
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
              ),

              const SizedBox(height: 32),

              // What do you need section
              Text(
                'What do you need?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),

              const SizedBox(height: 20),

              // Feature Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildFeatureCard(
                    icon: Icons.work,
                    title: 'Contracts',
                    color: Colors.orange[600]!,
                    onTap: () {
                      Navigator.pushNamed(context, '/contracts');
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.payment,
                    title: 'Payslip',
                    color: Colors.green[600]!,
                    onTap: () {
                      Navigator.pushNamed(context, '/payslips');
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.receipt_long,
                    title: 'Expenses',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pushNamed(context, '/expenses');
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.access_time,
                    title: 'Attendance',
                    color: Colors.grey[700]!,
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        '/attendance',
                        arguments: {
                          'isCheckedIn': _isCheckedIn,
                          'checkInDateTime': _checkInDateTime,
                          'checkInTime': _checkInTime,
                          'totalWorkedHours': _totalToday,
                        },
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.beach_access,
                    title: 'Time Off',
                    color: Colors.blue[600]!,
                    onTap: () {
                      Navigator.pushNamed(context, '/team-off');
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.calendar_today,
                    title: 'Working Schedule',
                    color: Colors.red[600]!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String time) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B46C1),
          ),
        ),
      ),
    );
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }
    
    return cardContent;
  }
} 