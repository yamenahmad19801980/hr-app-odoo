import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/contracts_screen.dart';
import 'screens/payslip_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/expense_create_screen.dart';
import 'screens/team_off_screen.dart';
import 'screens/face_attendance_screen.dart';
import 'config/odoo_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load Odoo configuration on app start
  await OdooConfig.loadConfiguration();
  
  runApp(const HrApp());
}

class HrApp extends StatelessWidget {
  const HrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          case '/attendance':
            return MaterialPageRoute(builder: (context) => const AttendanceScreen());
          case '/contracts':
            return MaterialPageRoute(builder: (context) => const ContractsScreen());
          case '/payslips':
            return MaterialPageRoute(builder: (context) => const PayslipScreen());
          case '/expenses':
            return MaterialPageRoute(builder: (context) => const ExpenseScreen());
          case '/expense-create':
            return MaterialPageRoute(builder: (context) => const ExpenseCreateScreen());
          case '/team-off':
            return MaterialPageRoute(builder: (context) => const TeamOffScreen());
          case '/face-attendance':
            return MaterialPageRoute(builder: (context) => const FaceAttendanceScreen());
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    );
  }
}
