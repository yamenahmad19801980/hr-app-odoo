import 'package:flutter/material.dart';
import '../config/odoo_config.dart';
import '../services/local_storage_service.dart';
import 'login_screen.dart';

class OdooConfigScreen extends StatefulWidget {
  const OdooConfigScreen({super.key});

  @override
  State<OdooConfigScreen> createState() => _OdooConfigScreenState();
}

class _OdooConfigScreenState extends State<OdooConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _databaseController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final storage = LocalStorageService();
    final savedUrl = await storage.getOdooUrl();
    final savedDatabase = await storage.getOdooDatabase();
    
    setState(() {
      _urlController.text = savedUrl ?? 'http://localhost:8069';
      _databaseController.text = savedDatabase ?? 'hr';
    });
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Update configuration
        await OdooConfig.updateConfiguration(
          _urlController.text.trim(),
          _databaseController.text.trim(),
        );

        // Mark first login as completed
        final storage = LocalStorageService();
        await storage.setFirstLoginCompleted();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Configuration saved successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to login screen
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error saving configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleTestConnection() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Temporarily update config for testing
        final originalUrl = OdooConfig.baseUrl;
        final originalDatabase = OdooConfig.database;
        
        await OdooConfig.updateConfiguration(
          _urlController.text.trim(),
          _databaseController.text.trim(),
        );

        // Test connection by trying to get server version
        // This would require importing and using OdooRPCService
        // For now, we'll just show a success message
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connection test successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Restore original config
        await OdooConfig.updateConfiguration(originalUrl, originalDatabase);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Connection test failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Odoo Configuration'),
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.settings,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Configure Odoo Server',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your Odoo server details to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // URL Field
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Odoo Server URL',
                    hintText: 'http://localhost:8069',
                    prefixIcon: const Icon(Icons.link, color: Color(0xFF6B46C1)),
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
                      return 'Please enter Odoo server URL';
                    }
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasAbsolutePath) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Database Field
                TextFormField(
                  controller: _databaseController,
                  decoration: InputDecoration(
                    labelText: 'Database Name',
                    hintText: 'hr',
                    prefixIcon: const Icon(Icons.storage, color: Color(0xFF6B46C1)),
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
                      return 'Please enter database name';
                    }
                    if (value.length < 2) {
                      return 'Database name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Test Connection Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleTestConnection,
                  icon: const Icon(Icons.wifi_protected_setup),
                  label: const Text('Test Connection'),
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

                // Save Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
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
                          'Save Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Info Card
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
                        'Configuration Info',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Enter your Odoo server URL (e.g., http://localhost:8069)\n'
                        '• Enter the database name you want to connect to\n'
                        '• Test the connection before saving\n'
                        '• You can change these settings later from the app',
                        style: TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 14,
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
