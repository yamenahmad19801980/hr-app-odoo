import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../config/odoo_config.dart';
import 'odoo_rpc_service.dart';

class FaceAttendanceService {
  static FaceAttendanceService? _instance;
  static FaceAttendanceService get instance => _instance ??= FaceAttendanceService._internal();
  
  FaceAttendanceService._internal();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCameraActive = false;

  // Getter for camera initialization status
  bool get isInitialized => _isInitialized;
  bool get isCameraActive => _isCameraActive;

  /// Initialize camera and permissions
  Future<bool> initializeCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        print('❌ Camera permission denied');
        return false;
      }

      // Request location permission
      final locationStatus = await Permission.location.request();
      if (locationStatus != PermissionStatus.granted) {
        print('❌ Location permission denied');
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print('❌ No cameras available');
        return false;
      }

      // Initialize camera controller with front camera if available
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isInitialized = true;
      
      print('✅ Camera initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing camera: $e');
      return false;
    }
  }

  /// Start camera preview
  Future<void> startCamera() async {
    if (_isInitialized && _cameraController != null) {
      try {
        await _cameraController!.resumePreview();
        _isCameraActive = true;
        print('✅ Camera started');
      } catch (e) {
        print('❌ Error starting camera: $e');
      }
    }
  }

  /// Stop camera preview
  Future<void> stopCamera() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.pausePreview();
        _isCameraActive = false;
        print('✅ Camera stopped');
      } catch (e) {
        print('❌ Error stopping camera: $e');
      }
    }
  }

  /// Get camera controller
  CameraController? get cameraController => _cameraController;

  /// Get available cameras
  List<CameraDescription>? get cameras => _cameras;

  /// Take a photo and get current location
  Future<Map<String, dynamic>> takeAttendancePhoto() async {
    try {
      if (!_isInitialized || _cameraController == null) {
        return {
          'success': false,
          'error': 'Camera not initialized',
        };
      }

      // Get current location
      final location = await _getCurrentLocation();
      if (location == null) {
        return {
          'success': false,
          'error': 'Could not get current location',
        };
      }

      // Take photo
      final image = await _cameraController!.takePicture();
      if (image == null) {
        return {
          'success': false,
          'error': 'Failed to capture image',
        };
      }

      // Convert image to base64
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Get address from coordinates
      final address = await _getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      return {
        'success': true,
        'image': base64Image,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': address,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error taking attendance photo: $e');
      return {
        'success': false,
        'error': 'Error taking photo: $e',
      };
    }
  }

  /// Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
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
        print('❌ Location permissions are permanently denied');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Get address from coordinates
  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
      }
      return 'Unknown location';
    } catch (e) {
      print('❌ Error getting address: $e');
      return 'Unknown location';
    }
  }

  /// Submit face attendance to Odoo with check-in/check-out logic
  Future<Map<String, dynamic>> submitFaceAttendance({
    required String base64Image,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      if (!OdooRPCService.instance.isAuthenticated) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login first.',
        };
      }

      // Check current attendance status
      final currentStatus = await getCurrentAttendanceStatus();
      final isCurrentlyCheckedIn = currentStatus['is_checked_in'] ?? false;
      final currentAttendanceId = currentStatus['attendance_id'];

      print('🔍 Current attendance status: ${isCurrentlyCheckedIn ? "Checked In" : "Checked Out"}');

      if (isCurrentlyCheckedIn) {
        // Perform check-out
        return await _performCheckOut(
          attendanceId: currentAttendanceId,
          latitude: latitude,
          longitude: longitude,
          address: address,
        );
      } else {
        // Perform check-in
        return await _performCheckIn(
          base64Image: base64Image,
          latitude: latitude,
          longitude: longitude,
          address: address,
        );
      }
    } catch (e) {
      print('❌ Error submitting face attendance: $e');
      return {
        'success': false,
        'error': 'Error submitting attendance: $e',
      };
    }
  }

  /// Get current attendance status
  Future<Map<String, dynamic>> getCurrentAttendanceStatus() async {
    try {
      final result = await _callOdooMethod(
        'hr.attendance',
        'search_read',
        [
          [['employee_id', '=', OdooRPCService.instance.currentEmployeeId], ['check_out', '=', false]],
          ['id', 'check_in', 'check_out'],
        ],
      );

      if (result['success'] && result['data'] != null && result['data'].isNotEmpty) {
        final attendance = result['data'][0];
        return {
          'is_checked_in': true,
          'attendance_id': attendance['id'],
          'check_in': attendance['check_in'],
        };
      }

      return {
        'is_checked_in': false,
        'attendance_id': null,
      };
    } catch (e) {
      print('❌ Error getting current attendance status: $e');
      return {
        'is_checked_in': false,
        'attendance_id': null,
      };
    }
  }

  /// Perform check-in
  Future<Map<String, dynamic>> _performCheckIn({
    required String base64Image,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final attendanceData = {
        'employee_id': OdooRPCService.instance.currentEmployeeId,
        'check_in': DateTime.now().toIso8601String(),
        'in_latitude': latitude,
        'in_longitude': longitude,
        'in_address': address ?? 'Unknown location',
        'face_image': base64Image,
      };

      print('🔍 Performing check-in with data: $attendanceData');

      final result = await _callOdooMethod(
        'hr.attendance',
        'create',
        [attendanceData],
      );

      if (result['success']) {
        print('✅ Check-in successful');
        return {
          'success': true,
          'action': 'check_in',
          'message': 'Successfully checked in with face recognition and location',
          'data': result['data'],
        };
      } else {
        return {
          'success': false,
          'action': 'check_in',
          'error': result['error'] ?? 'Failed to check in',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'action': 'check_in',
        'error': 'Exception during check-in: $e',
      };
    }
  }

  /// Perform check-out
  Future<Map<String, dynamic>> _performCheckOut({
    required int attendanceId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final checkoutData = {
        'check_out': DateTime.now().toIso8601String(),
        'out_latitude': latitude,
        'out_longitude': longitude,
        'out_address': address ?? 'Unknown location',
      };

      print('🔍 Performing check-out with data: $checkoutData');

      final result = await _callOdooMethod(
        'hr.attendance',
        'write',
        [attendanceId, checkoutData],
      );

      if (result['success']) {
        print('✅ Check-out successful');
        return {
          'success': true,
          'action': 'check_out',
          'message': 'Successfully checked out with location data',
          'data': result['data'],
        };
      } else {
        return {
          'success': false,
          'action': 'check_out',
          'error': result['error'] ?? 'Failed to check out',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'action': 'check_out',
        'error': 'Exception during check-out: $e',
      };
    }
  }

  /// Call Odoo method
  Future<Map<String, dynamic>> _callOdooMethod(
    String model,
    String method,
    List<dynamic> args,
  ) async {
    try {
      final url = Uri.parse('${OdooConfig.baseUrl}/jsonrpc');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'HR App Flutter Face Attendance',
          'Accept': 'application/json',
        },
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'service': 'object',
            'method': 'execute_kw',
            'args': [
              OdooRPCService.instance.currentDatabase,
              OdooRPCService.instance.currentUserId,
              OdooRPCService.instance.currentPassword,
              model,
              method,
              args,
            ],
          },
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['error'] != null) {
          return {
            'success': false,
            'error': jsonResponse['error']['data']['message'] ?? 'Odoo method call failed',
          };
        }

        return {
          'success': true,
          'data': jsonResponse['result'],
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: $e',
      };
    }
  }

  /// Dispose camera resources
  void dispose() {
    _cameraController?.dispose();
    _isInitialized = false;
    _isCameraActive = false;
  }
}
