import 'package:flutter/material.dart';
import '../models/hr_contract.dart';
import '../services/hr_service.dart';
import '../models/hr_employee.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final HrService _hrService = HrService();
  List<HrContract> _contracts = [];
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

      // Load contracts for the current employee only
      try {
        List<HrContract> contracts = await _hrService.getEmployeeContracts();

        // Calculate statistics based on employee contracts only
        final stats = _calculateEmployeeContractStatistics(contracts);

        setState(() {
          _contracts = contracts;
          _statistics = stats;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading contracts: $e');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Contract management is not available in your Odoo instance. Please contact your administrator to enable the HR Contracts module.';
        });
      }
    } catch (e) {
      print('Error loading employee data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading employee data: $e';
      });
    }
  }

  /// Calculate contract statistics for the current employee only
  Map<String, dynamic> _calculateEmployeeContractStatistics(List<HrContract> contracts) {
    if (contracts.isEmpty) {
      return {
        'total_contracts': 0,
        'active_contracts': 0,
        'expired_contracts': 0,
        'total_employees': 1, // Just the current employee
      };
    }

    int activeContracts = 0;
    int expiredContracts = 0;

    // Count contracts by state for this employee
    for (final contract in contracts) {
      try {
        if (contract.state == 'open') {
          // A contract is active if it's open
          activeContracts++;
        } else if (contract.state == 'close' || contract.state == 'cancel') {
          expiredContracts++;
        }
      } catch (e) {
        print('⚠️ Error processing contract ${contract.id}: $e');
        continue;
      }
    }

    return {
      'total_contracts': contracts.length,
      'active_contracts': activeContracts,
      'expired_contracts': expiredContracts,
      'total_employees': 1, // Just the current employee
    };
  }

  List<HrContract> get _filteredContracts {
    if (_selectedFilter == 'all') return _contracts;
    
    try {
      if (_selectedFilter == 'active') {
        return _contracts.where((c) => c.state == 'open').toList();
      }
      
      if (_selectedFilter == 'expired') {
        return _contracts.where((c) {
          return c.state == 'close' || c.state == 'cancel';
        }).toList();
      }
    } catch (e) {
      print('⚠️ Error filtering contracts: $e');
    }
    
    return _contracts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAdmin && _contracts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateContractDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildStatisticsCard(),
                    _buildFilterChips(),
                    Expanded(
                      child: _contracts.isEmpty
                          ? _buildEmptyState()
                          : _filteredContracts.isEmpty
                              ? _buildNoFilteredResults()
                              : _buildContractsList(),
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
          colors: [Colors.blue[700]!, Colors.blue[500]!],
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
                Icons.work,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Employee Contract Overview',
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
                  _statistics['total_contracts']?.toString() ?? '0',
                  Icons.description,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Active',
                  _statistics['active_contracts']?.toString() ?? '0',
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Expired',
                  _statistics['expired_contracts']?.toString() ?? '0',
                  Icons.warning,
                  color: Colors.orange,
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
          _buildFilterChip('all', 'All', Icons.all_inclusive, _contracts.length),
          _buildFilterChip('active', 'Active', Icons.check_circle, 
            _contracts.where((c) => c.state == 'open').length),
          _buildFilterChip('expired', 'Expired', Icons.warning, 
            _contracts.where((c) {
              return c.state == 'close' || c.state == 'cancel';
            }).length),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue[700] : Colors.grey[700],
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
        checkmarkColor: Colors.blue[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Contracts Not Available',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[700],
                side: BorderSide(color: Colors.blue[700]!),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
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
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No contracts found for this employee',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contracts will appear here once they are created for this employee',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateContractDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Contract'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No contracts found matching your filter',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filter or contact HR to create a new contract.',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateContractDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Contract'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredContracts.length,
      itemBuilder: (context, index) {
        final contract = _filteredContracts[index];
        return _buildContractCard(contract);
      },
    );
  }

  Widget _buildContractCard(HrContract contract) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showContractDetails(contract),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contract.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(contract.state ?? ''),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contract.employeeName ?? 'Unknown Employee',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contract.dateRangeDisplay,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contract.wageDisplay,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (contract.durationDays != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        '${contract.durationDays} days',
                        style: TextStyle(
                          color: Colors.blue[700],
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
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      case 'open':
        color = Colors.green;
        label = 'Active';
        break;
      case 'close':
        color = Colors.red;
        label = 'Closed';
        break;
      case 'cancel':
        color = Colors.orange;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showContractDetails(HrContract contract) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildContractDetailsSheet(contract),
    );
  }

  Widget _buildContractDetailsSheet(HrContract contract) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Employee Section
                  _buildSectionHeader('Employee Information', Icons.person),
                  _buildDetailRow('Employee', contract.employeeName ?? 'N/A'),
                  _buildDetailRow('Status', contract.statusDisplay),
                  
                  const SizedBox(height: 20),
                  
                  // Contract Dates Section
                  _buildSectionHeader('Contract Period', Icons.calendar_today),
                  _buildDetailRow('Start Date', 
                    contract.startDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                  _buildDetailRow('End Date', 
                    contract.endDate?.toLocal().toString().split(' ')[0] ?? 'Ongoing'),
                  if (contract.durationDays != null)
                    _buildDetailRow('Duration', '${contract.durationDays} days'),
                  
                  const SizedBox(height: 20),
                  
                  // Salary Details Section
                  _buildSectionHeader('Salary Details', Icons.attach_money),
                  _buildDetailRow('Wage', contract.wageDisplay),
                  _buildDetailRow('Contract Type', 'Full Time'), // Default value
                  
                  const SizedBox(height: 20),
                  
                  // System Information Section
                  _buildSectionHeader('System Information', Icons.info),
                  _buildDetailRow('Created', 
                    contract.createDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                  _buildDetailRow('Last Updated', 
                    contract.writeDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                  
                  const SizedBox(height: 20),
                  
                  if (_isAdmin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditContractDialog(contract);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteContract(contract);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              side: BorderSide(color: Colors.red[700]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.blue[700],
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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

  void _showCreateContractDialog() {
    // This would show a form to create a new contract
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create contract functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showEditContractDialog(HrContract contract) {
    // This would show a form to edit the contract
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit contract functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _deleteContract(HrContract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contract'),
        content: Text('Are you sure you want to delete "${contract.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Implement delete functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete contract functionality coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
