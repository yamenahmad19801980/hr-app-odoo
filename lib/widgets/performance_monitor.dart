import 'package:flutter/material.dart';
import 'package:hr_app_odoo/services/optimized_hr_service.dart';

class PerformanceMonitor extends StatelessWidget {
  final OptimizedHrService hrService;

  const PerformanceMonitor({
    super.key,
    required this.hrService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Performance Monitor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCacheStatusRow('Employees', 'employees'),
            _buildCacheStatusRow('Leaves', 'leaves'),
            _buildCacheStatusRow('Contracts', 'contracts'),
            _buildCacheStatusRow('Payslips', 'payslips'),
            _buildCacheStatusRow('Attendance', 'attendance'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await hrService.forceRefresh();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: Colors.blue[300]!),
                    ),
                    child: const Text(
                      'Force Refresh',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await hrService.clearAllCaches();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                    child: const Text(
                      'Clear Cache',
                      style: TextStyle(fontSize: 11, color: Colors.red),
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

  Widget _buildCacheStatusRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _getCacheHealth(key),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getCacheColor(key),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              _formatCacheAge(key),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getCacheHealth(String key) {
    final age = hrService.getCacheAge(key);
    if (age.inMinutes < 5) return 1.0;
    if (age.inMinutes < 15) return 0.7;
    if (age.inMinutes < 30) return 0.4;
    return 0.1;
  }

  Color _getCacheColor(String key) {
    final age = hrService.getCacheAge(key);
    if (age.inMinutes < 5) return Colors.green;
    if (age.inMinutes < 15) return Colors.orange;
    if (age.inMinutes < 30) return Colors.red;
    return Colors.grey;
  }

  String _formatCacheAge(String key) {
    final age = hrService.getCacheAge(key);
    if (age.inMinutes < 1) return 'now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    return '${age.inDays}d';
  }
}
