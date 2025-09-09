import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'odoo_config_screen.dart';
import '../services/odoo_rpc_service.dart';
import '../services/hr_service.dart';
import '../services/local_storage_service.dart';
import '../config/odoo_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if this is the first login and show configuration screen
  Future<void> _checkFirstLogin() async {
    try {
      // Load configuration first
      await OdooConfig.loadConfiguration();
      
      final storage = LocalStorageService();
      final isFirstLogin = await storage.isFirstLogin();
      
      if (isFirstLogin && mounted) {
        // Show configuration screen for first login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OdooConfigScreen()),
        );
      }
    } catch (e) {
      print('Error checking first login: $e');
    }
  }

  /// Open Odoo configuration screen
  Future<void> _openOdooConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OdooConfigScreen()),
    );
    
    // Reload configuration when returning from config screen
    if (mounted) {
      await OdooConfig.loadConfiguration();
      setState(() {
        // Update the UI to reflect new configuration
      });
    }
  }

  /// Clear form fields
  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _formKey.currentState?.reset();
  }

  /// Check if user is already logged in to the system
  Future<void> _checkExistingSession() async {
    try {
      print('🔍 Checking existing session for user: ${_emailController.text}');
      
      // Get current session information
      final sessionInfo = await OdooRPCService.instance.getSessionInfo();
      
      if (sessionInfo['success'] == true) {
        final data = sessionInfo['data'];
        final loginTime = data['login_time'];
        final sessionDuration = data['session_duration'];
        final isActive = data['is_active'] ?? false;
        
        print('📅 Session Info:');
        print('   Login Time: $loginTime');
        print('   Session Duration: $sessionDuration');
        print('   Is Active: $isActive');
        
        if (isActive) {
          // User is already logged in, show warning
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ User already has an active session. Previous session will be terminated.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Continue',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
          
          // Terminate previous session
          await _terminatePreviousSession();
        } else {
          print('✅ No active session found, proceeding with new login');
        }
      } else {
        print('❌ Could not retrieve session info: ${sessionInfo['error']}');
      }
    } catch (e) {
      print('❌ Error checking existing session: $e');
    }
  }

  /// Terminate previous session
  Future<void> _terminatePreviousSession() async {
    try {
      print('🔄 Terminating previous session...');
      
      final result = await OdooRPCService.instance.terminateSession();
      
      if (result['success'] == true) {
        print('✅ Previous session terminated successfully');
      } else {
        print('❌ Failed to terminate previous session: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error terminating previous session: $e');
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Attempt to authenticate
        print('Attempting authentication with: ${_emailController.text}');
        final result = await OdooRPCService.instance.authenticate(
          username: _emailController.text,
          password: _passwordController.text,
          database: OdooConfig.database,
        );

        print('Authentication result: $result');

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Set authenticated state
          setState(() {
            _isAuthenticated = true;
          });
          
          // Track login time
          await OdooRPCService.instance.trackLoginTime();
          
          // Debug: Show current state after authentication
          print('🔍 Debug - After authentication:');
          OdooRPCService.instance.debugState();
          
          // Check if user is already logged in to the system (but don't clear current session)
          await _checkExistingSession();
          
          // IMPORTANT: Get employee data for the authenticated user
          print('🔍 Fetching employee data for authenticated user...');
          try {
            final hrService = HrService();
            final employee = await hrService.getCurrentEmployee();
            
            if (employee != null) {
              print('✅ Employee data loaded successfully: ${employee.name} (ID: ${employee.id})');
              // Store employee ID in OdooRPCService for future use
              OdooRPCService.instance.setCurrentEmployeeId(employee.id);
              
              // Debug: Show state after setting employee ID
              print('🔍 Debug - After setting employee ID:');
              OdooRPCService.instance.debugState();
            } else {
              print('⚠️ No employee record found for user');
            }
          } catch (e) {
            print('❌ Error loading employee data: $e');
          }
          
          // Get the username from the email field
          final username = _emailController.text.split('@')[0]; // Extract username before @
          
          // Navigate to home screen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login successful! Welcome $username! 🎉'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // Wait a moment then navigate
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            });
          }
        } else {
            // Show error message with better formatting
            if (mounted) {
              String errorMessage = result['error'] ?? 'Unknown error';
              
              // Make the error message more user-friendly
              if (errorMessage.contains('Username or password is wrong')) {
                errorMessage = 'Username or password is wrong. Please check your credentials and try again.';
              } else if (errorMessage.contains('Failed to parse response')) {
                errorMessage = 'Authentication failed. Please try again.';
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'Try Again',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      _clearForm();
                    },
                  ),
                ),
              );
            }
          }
      } catch (e) {
        print('Login error: $e');
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // Logo and Title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Icon(
                          Icons.work,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'HR App Odoo',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to your account',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B46C1)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF6B46C1)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF6B46C1),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Odoo Configuration Button
                OutlinedButton.icon(
                  onPressed: _openOdooConfig,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure Odoo Server'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B46C1),
                    side: const BorderSide(color: Color(0xFF6B46C1)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Clear Form Button
                TextButton(
                  onPressed: _clearForm,
                  child: const Text(
                    'Clear Form',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Forgot Password
                TextButton(
                  onPressed: () {
                    // Handle forgot password
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF6B46C1),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Odoo Configuration Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Odoo Configuration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Server: ${OdooConfig.baseUrl}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Database: ${OdooConfig.database}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Session Status (if authenticated)
                if (_isAuthenticated) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Session Active',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'User authenticated successfully',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Demo Credentials
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Demo Credentials',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Email: admin@admin.com\nPassword: admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Use your actual Odoo credentials',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFA0AEC0),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 