import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hr_app_odoo/models/hr_leave.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Stream controller for broadcasting status changes
  final StreamController<HrLeave> _statusChangeController = StreamController<HrLeave>.broadcast();
  Stream<HrLeave> get statusChangeStream => _statusChangeController.stream;

  // Store previous statuses to detect changes
  final Map<int, String> _previousStatuses = <int, String>{};

  /// Initialize the notification service with current leave data
  void initializeWithLeaves(List<HrLeave> leaves) {
    for (final leave in leaves) {
      _previousStatuses[leave.id] = leave.state ?? 'draft';
    }
  }

  /// Check for status changes and notify if any are detected
  void checkStatusChanges(List<HrLeave> currentLeaves) {
    for (final leave in currentLeaves) {
      final previousStatus = _previousStatuses[leave.id];
      final currentStatus = leave.state ?? 'draft';
      
      if (previousStatus != null && previousStatus != currentStatus) {
        // Status has changed, notify
        print('🔔 Status change detected for leave ${leave.id}: $previousStatus -> $currentStatus');
        _notifyStatusChange(leave, previousStatus, currentStatus);
        _previousStatuses[leave.id] = currentStatus;
      } else if (previousStatus == null) {
        // New leave request
        _previousStatuses[leave.id] = currentStatus;
      }
    }
  }

  /// Notify about a status change
  void _notifyStatusChange(HrLeave leave, String oldStatus, String newStatus) {
    print('🔔 Broadcasting status change: ${leave.name} from $oldStatus to $newStatus');
    _statusChangeController.add(leave);
    
    // You can also add local notification here if needed
    // For now, we'll use the stream to update the UI
  }

  /// Get status change notification for a specific leave
  Widget buildStatusChangeNotification(HrLeave leave, String oldStatus, String newStatus) {
    final statusColors = {
      'draft': Colors.grey,
      'confirm': Colors.orange,
      'validate1': Colors.blue,
      'validate2': Colors.blue,
      'approve': Colors.green,
      'refuse': Colors.red,
      'cancel': Colors.red,
    };

    final oldColor = statusColors[oldStatus] ?? Colors.grey;
    final newColor = statusColors[newStatus] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: newColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: newColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(newStatus),
              color: newColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Updated',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${leave.leaveType ?? 'Leave'} request status changed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: oldColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: oldColor),
                      ),
                      child: Text(
                        _formatStatus(oldStatus),
                        style: TextStyle(
                          color: oldColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: newColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: newColor),
                      ),
                      child: Text(
                        _formatStatus(newStatus),
                        style: TextStyle(
                          color: newColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[400]),
            onPressed: () {
              // Remove notification logic can be added here
            },
          ),
        ],
      ),
    );
  }

  /// Get appropriate icon for status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.edit;
      case 'confirm':
        return Icons.schedule;
      case 'validate1':
      case 'validate2':
        return Icons.pending;
      case 'approve':
        return Icons.check_circle;
      case 'refuse':
        return Icons.cancel;
      case 'cancel':
        return Icons.block;
      default:
        return Icons.info;
    }
  }

  /// Format status for display
  String _formatStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'confirm':
        return 'To Approve';
      case 'validate1':
        return 'First Approval';
      case 'validate2':
        return 'Second Approval';
      case 'approve':
        return 'Approved';
      case 'refuse':
        return 'Refused';
      case 'cancel':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Dispose resources
  void dispose() {
    _statusChangeController.close();
  }
}
