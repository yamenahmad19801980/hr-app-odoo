import 'package:flutter/material.dart';
import '../models/hr_payslip.dart';
import '../services/hr_service.dart';
import '../models/hr_employee.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final HrService _hrService = HrService();
  List<HrPayslip> _payslips = [];
  HrEmployee? _currentEmployee;
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedFilter = 'all';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current employee
      final employee = await _hrService.getCurrentEmployee();
      if (employee != null) {
        _currentEmployee = employee;
        // Check if user is admin (you can modify this logic based on your needs)
        _isAdmin = employee.jobTitle?.toLowerCase().contains('admin') ?? false;
      }

      // Load payslips for the current employee only
      try {
        List<HrPayslip> payslips = await _hrService.getEmployeePayslips();

        // Calculate statistics based on employee payslips only
        final stats = _calculateEmployeePayslipStatistics(payslips);

        setState(() {
          _payslips = payslips;
          _statistics = stats;
          _isLoading = false;
        });
      } catch (e) {
        print('❌ Error loading payslips: $e');
        setState(() {
          _errorMessage = 'Failed to load payslips: ${e.toString()}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading employee data: $e');
      setState(() {
        _errorMessage = 'Failed to load employee data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Calculate payslip statistics for the current employee only
  Map<String, dynamic> _calculateEmployeePayslipStatistics(List<HrPayslip> payslips) {
    if (payslips.isEmpty) {
      return {
        'total_payslips': 0,
        'paid_payslips': 0,
        'verified_payslips': 0,
        'draft_payslips': 0,
        'total_employees': 1, // Just the current employee
      };
    }

    int paidPayslips = 0;
    int verifiedPayslips = 0;
    int draftPayslips = 0;

    // Count payslips by state for this employee
    for (final payslip in payslips) {
      try {
        if (payslip.state == 'draft') {
          draftPayslips++;
        } else if (payslip.state == 'verify') {
          verifiedPayslips++;
        } else if (payslip.state == 'done') {
          paidPayslips++;
        }
      } catch (e) {
        print('⚠️ Error processing payslip ${payslip.id}: $e');
        continue;
      }
    }

    return {
      'total_payslips': payslips.length,
      'paid_payslips': paidPayslips,
      'verified_payslips': verifiedPayslips,
      'draft_payslips': draftPayslips,
      'total_employees': 1, // Just the current employee
    };
  }

  List<HrPayslip> get _filteredPayslips {
    if (_selectedFilter == 'all') return _payslips;
    
    try {
      if (_selectedFilter == 'paid') {
        return _payslips.where((p) => p.state == 'done').toList();
      }
      
      if (_selectedFilter == 'verified') {
        return _payslips.where((p) => p.state == 'verify').toList();
      }
      
      if (_selectedFilter == 'draft') {
        return _payslips.where((p) => p.state == 'draft').toList();
      }
    } catch (e) {
      print('⚠️ Error filtering payslips: $e');
    }
    
    return _payslips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslips'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreatePayslipDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _payslips.isEmpty
                  ? _buildEmptyState()
                  : _filteredPayslips.isEmpty
                      ? _buildNoFilteredResults()
                      : Column(
                          children: [
                            _buildStatisticsCard(),
                            _buildFilterChips(),
                            Expanded(
                              child: _buildPayslipsList(),
                            ),
                          ],
                        ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Payslips',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Employee Payslip Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total',
                  _statistics['total_payslips']?.toString() ?? '0',
                  Icons.description,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Paid',
                  _statistics['paid_payslips']?.toString() ?? '0',
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Verified',
                  _statistics['verified_payslips']?.toString() ?? '0',
                  Icons.verified,
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Draft',
                  _statistics['draft_payslips']?.toString() ?? '0',
                  Icons.edit,
                  color: Colors.yellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'All', Icons.all_inclusive, _payslips.length),
          _buildFilterChip('paid', 'Paid', Icons.check_circle, 
            _payslips.where((p) => p.state == 'done').length),
          _buildFilterChip('verified', 'Verified', Icons.verified, 
            _payslips.where((p) => p.state == 'verify').length),
          _buildFilterChip('draft', 'Draft', Icons.edit, 
            _payslips.where((p) => p.state == 'draft').length),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, int count) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue[600] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[600],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payslips found for this employee',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payslips will appear here once they are generated for this employee',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFilteredResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payslips found matching your filter',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filter or contact HR to generate a new payslip.',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPayslips.length,
      itemBuilder: (context, index) {
        final payslip = _filteredPayslips[index];
        return _buildPayslipCard(payslip);
      },
    );
  }

  Widget _buildPayslipCard(HrPayslip payslip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(payslip.state),
          child: Icon(
            _getStatusIcon(payslip.state),
            color: Colors.white,
          ),
        ),
        title: Text(
          payslip.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Period: ${payslip.periodDisplay}'),
            Text('Status: ${payslip.statusDisplay}'),
            if (payslip.netWage != null)
              Text(
                'Net Wage: ${payslip.netWage!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => _showPayslipDetails(payslip),
        ),
        onTap: () => _showPayslipDetails(payslip),
      ),
    );
  }

  Color _getStatusColor(String? state) {
    switch (state) {
      case 'done':
        return Colors.green;
      case 'verify':
        return Colors.orange;
      case 'draft':
        return Colors.blue;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? state) {
    switch (state) {
      case 'done':
        return Icons.check_circle;
      case 'verify':
        return Icons.verified;
      case 'draft':
        return Icons.edit;
      case 'cancel':
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }

  void _showPayslipDetails(HrPayslip payslip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPayslipDetailsSheet(payslip),
    );
  }

  Widget _buildPayslipDetailsSheet(HrPayslip payslip) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getStatusColor(payslip.state),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(payslip.state),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payslip.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        payslip.statusDisplay,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Employee', payslip.employeeName ?? 'N/A'),
                  _buildDetailRow('Period', payslip.periodDisplay),
                  _buildDetailRow('Date Range', payslip.dateRangeDisplay),
                  _buildDetailRow('Status', payslip.statusDisplay),
                  const Divider(height: 32),
                  _buildDetailRow('Basic Wage', 
                    payslip.basicWage != null ? '\$${payslip.basicWage!.toStringAsFixed(2)}' : 'N/A'),
                  _buildDetailRow('Gross Wage', 
                    payslip.grossWage != null ? '\$${payslip.grossWage!.toStringAsFixed(2)}' : 'N/A'),
                  _buildDetailRow('Net Wage', 
                    payslip.netWage != null ? '\$${payslip.netWage!.toStringAsFixed(2)}' : 'N/A'),
                  const Divider(height: 32),
                  _buildDetailRow('Created', 
                    payslip.createDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                  _buildDetailRow('Last Updated', 
                    payslip.writeDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                ],
              ),
            ),
          ),
          if (_isAdmin)
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditPayslipDialog(payslip);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement payslip actions
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payslip actions coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Actions'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePayslipDialog() {
    // TODO: Implement create payslip dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create payslip functionality coming soon!')),
    );
  }

  void _showEditPayslipDialog(HrPayslip payslip) {
    // TODO: Implement edit payslip dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit payslip functionality coming soon!')),
    );
  }
}
