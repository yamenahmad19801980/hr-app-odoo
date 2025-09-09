import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../services/odoo_rpc_service.dart';
import '../services/hr_service.dart';
import '../config/odoo_config.dart';
import 'odoo_config_screen.dart';

class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen>
    with WidgetsBindingObserver {
  final HrService _hrService = HrService();
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraActive = false;
  bool _isLoading = false;
  bool _isLocationReady = false;
  bool _isCurrentlyCheckedIn = false;
  String _statusMessage = 'Initializing camera and location...';
  Position? _currentPosition;
  String? _currentAddress;
  String? _attendanceStatus;
  String? _capturedImagePath;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload Odoo configuration when returning from config screen
    OdooConfig.loadConfiguration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_isCameraInitialized) {
        _startCamera();
      }
    }
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing camera...';
    });

    try {
      // Initialize camera
      final cameraInitialized = await _initializeCamera();
      if (cameraInitialized) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Camera ready. Getting location...';
        });

        // Get current location
        final position = await _getCurrentLocation();
        if (position != null) {
                  setState(() {
          _currentPosition = position;
          _isLocationReady = true;
          _statusMessage = 'Ready for face-verified attendance!';
        });
        } else {
          setState(() {
            _statusMessage = 'Location unavailable. Attendance may fail geofence validation.';
          });
        }

        // Check current attendance status
        await _checkCurrentAttendanceStatus();
      } else {
        setState(() {
          _statusMessage = 'Failed to initialize camera. Using location-only mode.';
        });
        // Fallback to location-only mode
        final position = await _getCurrentLocation();
        if (position != null) {
          setState(() {
            _currentPosition = position;
            _isLocationReady = true;
            _statusMessage = 'Location ready. Camera unavailable.';
          });
        }
        await _checkCurrentAttendanceStatus();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        print('❌ Camera permission denied');
        return false;
      }

      print('🔍 Getting available cameras...');
      
      // Get available cameras
      _cameras = await availableCameras();
      print('🔍 Found ${_cameras?.length ?? 0} cameras');
      
      if (_cameras == null || _cameras!.isEmpty) {
        print('❌ No cameras available');
        return false;
      }

      // List all available cameras for debugging
      for (int i = 0; i < _cameras!.length; i++) {
        final camera = _cameras![i];
        print('🔍 Camera $i: ${camera.name} (${camera.lensDirection})');
      }

      // Try to find front camera first, then any available camera
      CameraDescription? selectedCamera;
      
      try {
        selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        print('✅ Selected front camera: ${selectedCamera.name}');
      } catch (e) {
        print('⚠️ No front camera found, using first available camera');
        selectedCamera = _cameras!.first;
      }

      print('🔍 Initializing camera controller with: ${selectedCamera.name}');
      
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888, // Better Windows compatibility
      );

      print('🔍 Waiting for camera initialization...');
      await _cameraController!.initialize();
      print('✅ Camera initialized successfully');
      
      return true;
    } catch (e) {
      print('❌ Error initializing camera: $e');
      print('❌ Error details: ${e.toString()}');
      return false;
    }
  }

  Future<void> _startCamera() async {
    if (_isCameraInitialized && _cameraController != null) {
      try {
        await _cameraController!.resumePreview();
        setState(() {
          _isCameraActive = true;
        });
        print('✅ Camera started');
      } catch (e) {
        print('❌ Error starting camera: $e');
      }
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.pausePreview();
        setState(() {
          _isCameraActive = false;
        });
        print('✅ Camera stopped');
      } catch (e) {
        print('❌ Error stopping camera: $e');
      }
    }
  }

  Future<void> _checkCurrentAttendanceStatus() async {
    try {
      // Check if user is currently checked in by looking for open attendance records
      final result = await OdooRPCService.instance.searchRead(
        model: 'hr.attendance',
        domain: [
          ['employee_id', '=', OdooRPCService.instance.currentEmployeeId],
          ['check_out', '=', false]
        ],
        fields: ['id', 'check_in'],
      );

      if (result['success'] && result['data'] != null && result['data'].isNotEmpty) {
        setState(() {
          _isCurrentlyCheckedIn = true;
        });
      } else {
        setState(() {
          _isCurrentlyCheckedIn = false;
        });
      }
    } catch (e) {
      print('Could not check attendance status: $e');
      setState(() {
        _isCurrentlyCheckedIn = false;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          _currentAddress = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
        }
      } catch (e) {
        print('Could not get address: $e');
      }

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<void> _takeFaceAttendance() async {
    // Location is optional for face attendance - face recognition is the primary validation
    if (!_isLocationReady || _currentPosition == null) {
      print('⚠️ Location not ready, proceeding with face-only attendance');
      // Continue with face attendance even without location
    }

    if (_isCameraInitialized && !_isCameraActive) {
      // Start camera first
      await _startCamera();
      setState(() {});
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Taking face attendance...';
      _lastError = null; // Clear previous error
    });

    try {
      String? faceImage;
      
             // Take photo if camera is available
       if (_isCameraInitialized && _cameraController != null && _isCameraActive) {
         try {
           print('🔍 Taking photo...');
           final image = await _cameraController!.takePicture();
           if (image != null) {
             print('🔍 Photo captured at: ${image.path}');
             final imageFile = File(image.path);
             
             // Check if file exists
             if (!await imageFile.exists()) {
               print('❌ Image file does not exist at path: ${image.path}');
               return;
             }
             
             final imageBytes = await imageFile.readAsBytes();
             print('🔍 Image bytes length: ${imageBytes.length}');
             
             if (imageBytes.isEmpty) {
               print('❌ Image bytes are empty');
               return;
             }
             
             faceImage = base64Encode(imageBytes);
             print('🔍 Base64 encoded length: ${faceImage.length}');
             
             if (faceImage.isEmpty) {
               print('❌ Base64 encoding failed - result is empty');
               return;
             }
             
             print('🔍 Base64 starts with: ${faceImage.substring(0, 20)}...');
             setState(() {
               _capturedImagePath = faceImage;
             });
           } else {
             print('❌ Photo capture returned null');
           }
         } catch (e) {
           print('❌ Error taking photo: $e');
         }
       } else {
         print('❌ Camera not ready: initialized=$_isCameraInitialized, controller=${_cameraController != null}, active=$_isCameraActive');
       }

             // Ensure we have a face image before proceeding
       if (faceImage == null || faceImage.isEmpty) {
         setState(() {
           _attendanceStatus = '❌ Failed to capture face image. Please try again.';
           _statusMessage = 'Face image capture failed. Please try again.';
         });
         _showSnackBar('Failed to capture face image', isSuccess: false);
         return;
       }
       
       print('🔍 Face image captured successfully, length: ${faceImage.length}');
       
       if (_isCurrentlyCheckedIn) {
         // Perform check-out
         final result = await _performCheckOut(faceImage);
        if (result) {
          setState(() {
            _attendanceStatus = '✅ Successfully checked out with face and location!';
            _statusMessage = 'Check-out recorded successfully.';
            _isCurrentlyCheckedIn = false;
          });
          _showSnackBar('Check-out successful!', isSuccess: true);
        } else {
          setState(() {
            _attendanceStatus = '❌ Check-out failed. ${_lastError ?? "Please try again."}';
            _statusMessage = 'Check-out failed. Please try again.';
          });
          _showSnackBar('Check-out failed. ${_lastError ?? "Please try again."}', isSuccess: false);
        }
      } else {
        // Perform check-in
        final result = await _performCheckIn(faceImage);
        if (result) {
          setState(() {
            _attendanceStatus = '✅ Successfully checked in with face and location!';
            _statusMessage = 'Check-in recorded successfully.';
            _isCurrentlyCheckedIn = true;
          });
          _showSnackBar('Check-in successful!', isSuccess: true);
        } else {
          setState(() {
            _attendanceStatus = '❌ Check-in failed. ${_lastError ?? "Face not recognized - no matching employee found in database."}';
            _statusMessage = 'Check-in failed. Please try again.';
          });
          _showSnackBar('Check-in failed. ${_lastError ?? "Face not recognized - no matching employee found in database."}', isSuccess: false);
        }
      }

      // Stop camera after taking attendance
      await _stopCamera();

      // Clear status after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _attendanceStatus = null;
            _capturedImagePath = null;
            _statusMessage = 'Ready for face-verified attendance!';
          });
        }
      });
    } catch (e) {
      print('❌ Error taking attendance: $e');
      setState(() {
        _attendanceStatus = '❌ Error taking attendance: $e';
        _statusMessage = 'Error occurred. Please try again.';
      });
      _showSnackBar('Error taking attendance: $e', isSuccess: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _performCheckIn(String? faceImage) async {
    try {
      print('🔍 Starting check-in process...');
      
             // First, verify face with your Odoo face recognition system
       if (faceImage != null && faceImage.isNotEmpty) {
         print('🔍 Verifying face with Odoo face recognition...');
         print('🔍 Face image to verify length: ${faceImage.length}');
         final faceVerificationResult = await _verifyFaceWithOdoo(faceImage);
        
        if (!faceVerificationResult['success']) {
          print('❌ Face verification failed: ${faceVerificationResult['message']}');
          setState(() {
            _attendanceStatus = '❌ Face verification failed: ${faceVerificationResult['message']}';
          });
          return false;
        }
        
        print('✅ Face verified successfully: ${faceVerificationResult['message']}');
      } else {
        print('❌ No face image for verification');
        setState(() {
          _attendanceStatus = '❌ Face image required for check-in';
        });
        return false;
      }
      
      // Format data exactly like your Odoo model supports
      // Your aptuem_attendance_location module only supports these fields
      final attendanceData = {
        'employee_id': OdooRPCService.instance.currentEmployeeId,
        'check_in': DateTime.now().toUtc().toString().substring(0, 19), // Format: 2025-08-28 02:24:17
        'in_latitude': _currentPosition?.latitude ?? 0.0,
        'in_longitude': _currentPosition?.longitude ?? 0.0,
      };

      print('🔍 Check-in data to send: $attendanceData');

      final result = await OdooRPCService.instance.create(
        model: 'hr.attendance',
        values: attendanceData,
      );

      print('🔍 Create result: $result');
      
      if (!(result['success'] ?? false)) {
        print('❌ Check-in failed: ${result['error']}');
        // Store the error message for display
        _lastError = result['error'] ?? 'Unknown error';
      }
      
      return result['success'] ?? false;
    } catch (e) {
      print('❌ Error during check-in: $e');
      print('❌ Error details: ${e.toString()}');
      return false;
    }
  }

  Future<bool> _performCheckOut(String? faceImage) async {
    try {
      print('🔍 Starting check-out process...');
      
      // Find the current open attendance record
      final result = await OdooRPCService.instance.searchRead(
        model: 'hr.attendance',
        domain: [
          ['employee_id', '=', OdooRPCService.instance.currentEmployeeId],
          ['check_out', '=', false]
        ],
        fields: ['id'],
      );

      print('🔍 Search result: $result');

      if (result['success'] && result['data'] != null && result['data'].isNotEmpty) {
        final attendanceId = result['data'][0]['id'];
        print('✅ Found attendance record ID: $attendanceId');
        
        // Format data exactly like your Odoo model supports
        // Note: Your aptuem_attendance_location module only has in_latitude/in_longitude
        final checkoutData = {
          'check_out': DateTime.now().toUtc().toString().substring(0, 19), // Format: 2025-08-28 02:24:17
          // Only send fields that exist in your Odoo model
          // 'out_latitude' and 'out_longitude' don't exist in your model
        };

        // Note: Your Odoo model doesn't support out_face_image field
        // Only check-in supports face_image for validation
        if (faceImage != null) {
          print('ℹ️ Face image captured but not sent for check-out (field not supported)');
        }

        print('🔍 Check-out data to send: $checkoutData');

        // Update the attendance record with check-out time and location
        print('🔍 Sending write request to Odoo...');
        final updateResult = await OdooRPCService.instance.write(
          model: 'hr.attendance',
          recordId: attendanceId,
          values: checkoutData,
        );

        print('🔍 Write result: $updateResult');
        
        if (!(updateResult['success'] ?? false)) {
          print('❌ Check-out failed: ${updateResult['error']}');
          // Store the error message for display
          _lastError = updateResult['error'] ?? 'Unknown error';
        }
        
        return updateResult['success'] ?? false;
      } else {
        print('❌ No open attendance record found');
        print('❌ Search result: $result');
        return false;
      }
    } catch (e) {
      print('❌ Error during check-out: $e');
      print('❌ Error details: ${e.toString()}');
      return false;
    }
  }

  // Face verification method that integrates with your Odoo face recognition system
  Future<Map<String, dynamic>> _verifyFaceWithOdoo(String faceImage) async {
    try {
      print('🔍 Verifying face with Odoo face recognition system...');
      
             // Get Odoo base URL from configuration
       final baseUrl = OdooConfig.baseUrl;
       print('🔍 Using Odoo server URL: $baseUrl');
      
             // Prepare the data exactly like your Odoo controller expects
       // Your Odoo controller expects data:image/jpeg;base64, format
       final formData = {
         'face_image': 'data:image/jpeg;base64,$faceImage',
         'latitude': _currentPosition?.latitude.toString() ?? '0.0',
         'longitude': _currentPosition?.longitude.toString() ?? '0.0',
       };

             // Ensure no double slash in URL
             final endpointUrl = baseUrl.endsWith('/') 
                 ? '${baseUrl}submit_face' 
                 : '$baseUrl/submit_face';
             print('🔍 Sending to Odoo endpoint: $endpointUrl');
       print('🔍 Face image length: ${faceImage.length} characters');
       print('🔍 Form data keys: ${formData.keys.toList()}');
       print('🔍 Latitude: ${formData['latitude']}');
       print('🔍 Longitude: ${formData['longitude']}');
       print('🔍 Face image starts with: ${formData['face_image']?.substring(0, 50)}...');

             // Send POST request to your Odoo controller
       print('🔍 Sending HTTP POST request...');
       final response = await http.post(
         Uri.parse(endpointUrl),
         body: formData,
         headers: {
           'Content-Type': 'application/x-www-form-urlencoded',
         },
       );
       print('🔍 HTTP request completed');

      print('🔍 Odoo response status: ${response.statusCode}');
      print('🔍 Odoo response body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response to check if face was recognized
        final responseBody = response.body;
        print('🔍 Parsing response body for face recognition result...');
        
        if (responseBody.contains('✅ Success:')) {
          // Extract employee name and status from response
          final successMatch = RegExp(r'✅ Success: (.+?) - (.+)').firstMatch(responseBody);
          if (successMatch != null) {
            final employeeName = successMatch.group(1);
            final status = successMatch.group(2);
            print('✅ Face verified successfully for: $employeeName - $status');
            return {
              'success': true,
              'message': 'Face verified for $employeeName',
              'employeeName': employeeName,
              'status': status,
            };
          }
        } else if (responseBody.contains('⚠️ No face detected')) {
          print('⚠️ No face detected in image');
          return {
            'success': false,
            'message': 'No face detected in image',
          };
        } else if (responseBody.contains('⚠️ No matching face found') || 
                   responseBody.contains('! No matching face found') ||
                   responseBody.contains('No matching face found')) {
          print('! No matching face found in database');
          return {
            'success': false,
            'message': 'Face not recognized - no matching employee found in database',
          };
        } else if (responseBody.contains('You are outside all allowed attendance locations') ||
                   responseBody.contains('No matching location found within radius')) {
          print('⚠️ Location error: Outside allowed attendance locations');
          return {
            'success': false,
            'message': 'You are outside all allowed attendance locations. No matching location found within radius.',
          };
        } else if (responseBody.contains('❌ Error:')) {
          final errorMatch = RegExp(r'❌ Error: (.+)').firstMatch(responseBody);
          final errorMessage = errorMatch?.group(1) ?? 'Unknown error';
          print('❌ Face recognition error: $errorMessage');
          return {
            'success': false,
            'message': 'Face recognition error: $errorMessage',
          };
        }
        
        // If we get here, the response doesn't match expected patterns
        print('⚠️ Unexpected response format from face recognition system');
        print('🔍 Response content: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}...');
        
        // Check if it's a location error in the response body
        if (responseBody.contains('outside') && responseBody.contains('location')) {
          return {
            'success': false,
            'message': 'You are outside all allowed attendance locations. No matching location found within radius.',
          };
        }
        
        // Default failure case for unrecognized response
        return {
          'success': false,
          'message': 'Face recognition system returned unexpected response',
        };
      } else {
        print('❌ Odoo face verification failed: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error verifying face with Odoo: $e');
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Test method to send face attendance directly to your Odoo endpoint
  Future<bool> _testOdooFaceEndpoint(String? faceImage) async {
    try {
      print('🔍 Testing direct Odoo face attendance endpoint...');
      
      if (faceImage == null) {
        print('❌ No face image to send');
        return false;
      }

      // Use the same verification method
      final result = await _verifyFaceWithOdoo(faceImage);
      return result['success'] ?? false;
    } catch (e) {
      print('❌ Error testing Odoo endpoint: $e');
      return false;
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openOdooConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OdooConfigScreen()),
    );
    
    // Reload configuration when returning from config screen
    if (result != null || mounted) {
      await OdooConfig.loadConfiguration();
      if (mounted) {
        setState(() {
          // Update the UI to reflect new configuration
        });
      }
    }
  }

  Future<void> _testOdooConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing Odoo connection...';
    });

    try {
      final baseUrl = OdooConfig.baseUrl;
      print('🔍 Testing connection to: $baseUrl');
      
      final response = await http.get(
        Uri.parse('$baseUrl/web'),
        headers: {
          'User-Agent': 'HR App Flutter',
        },
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _statusMessage = '✅ Odoo connection successful!';
          });
          _showSnackBar('Odoo server is reachable!', isSuccess: true);
        } else {
          setState(() {
            _statusMessage = '❌ Odoo connection failed (${response.statusCode})';
          });
          _showSnackBar('Odoo server returned ${response.statusCode}', isSuccess: false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Connection error: $e';
        });
        _showSnackBar('Connection failed: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
             appBar: AppBar(
         title: const Text('Face-Verified Attendance'),
         backgroundColor: Colors.blue[700],
         foregroundColor: Colors.white,
         actions: [
           IconButton(
             onPressed: _openOdooConfig,
             icon: const Icon(Icons.settings),
             tooltip: 'Odoo Configuration',
           ),
         ],
       ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCurrentlyCheckedIn ? Icons.logout : Icons.login,
                            color: _isCurrentlyCheckedIn ? Colors.red : Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCurrentlyCheckedIn ? 'Currently Checked In' : 'Currently Checked Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isCurrentlyCheckedIn ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCameraInitialized ? Icons.camera_alt : Icons.camera_alt_outlined,
                            color: _isCameraInitialized ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isLocationReady ? Icons.location_on : Icons.location_off,
                            color: _isLocationReady ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Odoo Configuration Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings,
                              size: 14,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Odoo: ${OdooConfig.baseUrl}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                                             if (_attendanceStatus != null) ...[
                         const SizedBox(height: 8),
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             color: _attendanceStatus!.contains('✅') 
                                 ? Colors.green[50] 
                                 : Colors.red[50],
                             borderRadius: BorderRadius.circular(8),
                             border: Border.all(
                               color: _attendanceStatus!.contains('✅') 
                                   ? Colors.green 
                                   : Colors.red,
                               width: 1,
                             ),
                           ),
                           child: Text(
                             _attendanceStatus!,
                             style: TextStyle(
                               fontSize: 14,
                               color: _attendanceStatus!.contains('✅') 
                                   ? Colors.green[700] 
                                   : Colors.red[700],
                               fontWeight: FontWeight.w500,
                             ),
                             textAlign: TextAlign.center,
                           ),
                         ),
                       ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // Camera Preview or Captured Image
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _capturedImagePath != null
                      ? Image.memory(
                          base64Decode(_capturedImagePath!),
                          fit: BoxFit.cover,
                        )
                      : _isCameraActive && _isCameraInitialized
                          ? CameraPreview(_cameraController!)
                          : Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isCameraInitialized ? Icons.camera_alt : Icons.camera_alt_outlined,
                                      size: 64,
                                      color: _isCameraInitialized ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _isCameraInitialized 
                                          ? (_isCameraActive ? 'Camera Active' : 'Camera Ready')
                                          : 'Camera Unavailable',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _isCameraInitialized ? Colors.blue : Colors.grey,
                                      ),
                                    ),
                                    if (_isCameraInitialized && !_isCameraActive) ...[
                                      const SizedBox(height: 8),
                                                                           Text(
                                       'Tap Check In/Out to start face verification',
                                       style: TextStyle(
                                         fontSize: 14,
                                         color: Colors.grey[600],
                                       ),
                                     ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                ),
              ),

              const SizedBox(height: 20),

              // Location Info
              if (_currentPosition != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const Text(
                          'Current Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (_currentAddress != null)
                          Text(
                            _currentAddress!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

                             // Main Toggle Button - Check In/Out
               Row(
                 children: [
                   Expanded(
                     child: ElevatedButton.icon(
                       onPressed: _isLoading
                           ? null
                           : _takeFaceAttendance,
                       icon: _isLoading
                           ? const SizedBox(
                               width: 20,
                               height: 20,
                               child: CircularProgressIndicator(strokeWidth: 2),
                             )
                           : Icon(_isCurrentlyCheckedIn ? Icons.logout : Icons.login),
                                               label: Text(_isLoading 
                            ? 'Processing...' 
                            : _isCurrentlyCheckedIn 
                                ? 'Check Out (Face Verified)' 
                                : 'Check In (Face Verified)'),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: _isCurrentlyCheckedIn ? Colors.red : Colors.green,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8),
                         ),
                       ),
                     ),
                   ),
                 ],
               ),

               const SizedBox(height: 16),

               // Test Odoo Endpoint Button
               if (_capturedImagePath != null)
                 Row(
                   children: [
                     Expanded(
                       child: OutlinedButton.icon(
                         onPressed: _isLoading ? null : () => _testOdooFaceEndpoint(_capturedImagePath),
                         icon: const Icon(Icons.api),
                         label: const Text('Test Face Recognition'),
                         style: OutlinedButton.styleFrom(
                           foregroundColor: Colors.blue,
                           side: const BorderSide(color: Colors.blue),
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),

               const SizedBox(height: 16),

               // Configuration Test Button
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: _isLoading ? null : _testOdooConnection,
                       icon: const Icon(Icons.wifi_protected_setup),
                       label: const Text('Test Odoo Connection'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.green,
                         side: const BorderSide(color: Colors.green),
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
      ),
    );
  }
}
