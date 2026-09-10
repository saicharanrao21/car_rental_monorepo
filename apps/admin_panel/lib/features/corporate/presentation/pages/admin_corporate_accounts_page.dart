import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/api_providers.dart';

class AdminCorporateAccountsPage extends ConsumerStatefulWidget {
  const AdminCorporateAccountsPage({super.key});

  @override
  ConsumerState<AdminCorporateAccountsPage> createState() =>
      _AdminCorporateAccountsPageState();
}

class _AdminCorporateAccountsPageState
    extends ConsumerState<AdminCorporateAccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _accounts = [];
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final queryParams = <String, dynamic>{};
      final query = _searchController.text.trim();
      if (query.isNotEmpty) queryParams['query'] = query;
      if (_activeFilter != null) queryParams['isActive'] = _activeFilter;

      final res = await apiClient.dio.get(
        '/api/v1/corporate-accounts',
        queryParameters: queryParams,
      );

      if (mounted) {
        setState(() {
          if (res.data is Map && res.data['data'] is List) {
            _accounts = res.data['data'] as List<dynamic>;
          } else if (res.data is List) {
            _accounts = res.data as List<dynamic>;
          } else {
            _accounts = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load corporate accounts: $e';
        });
      }
    }
  }

  Future<void> _openCreateAccountDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final creditCtrl = TextEditingController(text: '50000');
    final discountCtrl = TextEditingController(text: '10');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Corporate Account'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Company Name *'),
                ),
                const Gap(8),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Corporate Code (e.g. CORP_GOOGLE) *'),
                ),
                const Gap(8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Email *'),
                ),
                const Gap(8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Phone *'),
                ),
                const Gap(8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Billing Address *'),
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: creditCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Credit Limit (₹)'),
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Discount %'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );

    if (created != true) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post(
        '/api/v1/corporate-accounts',
        data: {
          'companyName': nameCtrl.text.trim(),
          'corporateCode': codeCtrl.text.trim().toUpperCase(),
          'contactEmail': emailCtrl.text.trim(),
          'contactPhone': phoneCtrl.text.trim(),
          'billingAddress': addressCtrl.text.trim().isEmpty ? 'Bangalore, India' : addressCtrl.text.trim(),
          'creditLimit': double.tryParse(creditCtrl.text) ?? 50000,
          'negotiatedDiscountPct': double.tryParse(discountCtrl.text) ?? 10,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corporate account created successfully.')),
        );
        _fetchAccounts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create account: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _inspectAccount(Map<String, dynamic> account) async {
    final accountId = account['id'].toString();

    // Fetch employees and credit ledger in parallel
    List<dynamic> employees = [];
    List<dynamic> ledger = [];

    try {
      final apiClient = ref.read(apiClientProvider);
      final [empRes, ledRes] = await Future.wait([
        apiClient.dio.get('/api/v1/corporate-accounts/$accountId/employees'),
        apiClient.dio.get('/api/v1/corporate-accounts/$accountId/credit-ledger'),
      ]);

      if (empRes.data is List) employees = empRes.data as List<dynamic>;
      if (ledRes.data is List) ledger = ledRes.data as List<dynamic>;
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setDrawerState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['companyName']?.toString() ?? 'Corporate Account',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Code: ${account['corporateCode']} • Credit Limit: ₹${account['creditLimit']}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Overview & Credit'),
                    Tab(text: 'Authorized Employees'),
                    Tab(text: 'Credit Ledger History'),
                  ],
                ),
                const Gap(16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Overview
                      ListView(
                        children: [
                          _buildDetailRow('Company Name', account['companyName']?.toString() ?? '-'),
                          _buildDetailRow('Corporate Code', account['corporateCode']?.toString() ?? '-'),
                          _buildDetailRow('Contact Email', account['contactEmail']?.toString() ?? '-'),
                          _buildDetailRow('Contact Phone', account['contactPhone']?.toString() ?? '-'),
                          _buildDetailRow('Billing Address', account['billingAddress']?.toString() ?? '-'),
                          _buildDetailRow('Negotiated Discount', '${account['negotiatedDiscountPct'] ?? 0}%'),
                          _buildDetailRow('Credit Limit', '₹${account['creditLimit']}'),
                          _buildDetailRow('Used Credit', '₹${account['usedCredit']}'),
                          _buildDetailRow(
                            'Available Credit',
                            '₹${((double.tryParse(account['creditLimit'].toString()) ?? 0) - (double.tryParse(account['usedCredit'].toString()) ?? 0)).toStringAsFixed(2)}',
                          ),
                          _buildDetailRow('Status', account['isActive'] == true ? 'ACTIVE' : 'SUSPENDED'),
                        ],
                      ),

                      // Tab 2: Employees
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Authorized: ${employees.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              FilledButton.icon(
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Add Employee'),
                                onPressed: () async {
                                  final userCtrl = TextEditingController();
                                  final empCodeCtrl = TextEditingController();
                                  final deptCtrl = TextEditingController();
                                  final limitCtrl = TextEditingController(text: '25000');

                                  final added = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Add Corporate Employee'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: userCtrl,
                                            decoration: const InputDecoration(labelText: 'User ID *'),
                                          ),
                                          const Gap(8),
                                          TextField(
                                            controller: empCodeCtrl,
                                            decoration: const InputDecoration(labelText: 'Employee Code'),
                                          ),
                                          const Gap(8),
                                          TextField(
                                            controller: deptCtrl,
                                            decoration: const InputDecoration(labelText: 'Department'),
                                          ),
                                          const Gap(8),
                                          TextField(
                                            controller: limitCtrl,
                                            decoration: const InputDecoration(labelText: 'Monthly Limit (₹)'),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        FilledButton(
                                          onPressed: () {
                                            if (userCtrl.text.isEmpty) return;
                                            Navigator.pop(c, true);
                                          },
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (added != true) return;

                                  try {
                                    final apiClient = ref.read(apiClientProvider);
                                    await apiClient.dio.post(
                                      '/api/v1/corporate-accounts/$accountId/employees',
                                      data: {
                                        'userId': userCtrl.text.trim(),
                                        if (empCodeCtrl.text.isNotEmpty) 'employeeCode': empCodeCtrl.text.trim(),
                                        if (deptCtrl.text.isNotEmpty) 'department': deptCtrl.text.trim(),
                                        if (limitCtrl.text.isNotEmpty) 'spendingLimitMonthly': double.tryParse(limitCtrl.text),
                                      },
                                    );
                                    final refetch = await apiClient.dio.get('/api/v1/corporate-accounts/$accountId/employees');
                                    if (refetch.data is List) {
                                      setDrawerState(() {
                                        employees = refetch.data as List<dynamic>;
                                      });
                                    }
                                  } catch (err) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                                        SnackBar(content: Text('Failed to add employee: $err'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const Gap(12),
                          Expanded(
                            child: employees.isEmpty
                                ? const Center(child: Text('No employees authorized yet.'))
                                : ListView.builder(
                                    itemCount: employees.length,
                                    itemBuilder: (c, i) {
                                      final e = employees[i] as Map<String, dynamic>;
                                      final isActive = e['isActive'] == true;
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            child: Text((e['user']?['name'] ?? 'E')[0]),
                                          ),
                                          title: Text(e['user']?['name'] ?? e['userId']),
                                          subtitle: Text(
                                            'Code: ${e['employeeCode'] ?? '-'} • Dept: ${e['department'] ?? '-'}\n'
                                            'Monthly Limit: ₹${e['spendingLimitMonthly'] ?? 'Unlimited'} • Spent: ₹${e['spentThisMonth'] ?? 0}',
                                          ),
                                          trailing: Switch(
                                            value: isActive,
                                            onChanged: (val) async {
                                              try {
                                                final apiClient = ref.read(apiClientProvider);
                                                await apiClient.dio.patch(
                                                  '/api/v1/corporate-accounts/$accountId/employees/${e['id']}/status',
                                                  data: {'isActive': val},
                                                );
                                                final refetch = await apiClient.dio.get('/api/v1/corporate-accounts/$accountId/employees');
                                                if (refetch.data is List) {
                                                  setDrawerState(() {
                                                    employees = refetch.data as List<dynamic>;
                                                  });
                                                }
                                              } catch (_) {}
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),

                      // Tab 3: Credit Ledger
                      ledger.isEmpty
                          ? const Center(child: Text('No credit ledger activity recorded yet.'))
                          : ListView.builder(
                              itemCount: ledger.length,
                              itemBuilder: (c, i) {
                                final l = ledger[i] as Map<String, dynamic>;
                                final action = l['action']?.toString() ?? 'RESERVATION';
                                final amount = double.tryParse(l['amount'].toString()) ?? 0.0;
                                final balanceAfter = double.tryParse(l['balanceAfter'].toString()) ?? 0.0;
                                final color = action == 'RESERVATION'
                                    ? Colors.amber[800]
                                    : (action == 'RELEASE' ? Colors.blue : Colors.green);

                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      action == 'RESERVATION'
                                          ? Icons.lock_clock
                                          : (action == 'RELEASE' ? Icons.lock_open : Icons.check_circle),
                                      color: color,
                                    ),
                                    title: Text(
                                      '$action: ₹${amount.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                    ),
                                    subtitle: Text(
                                      'Balance After: ₹${balanceAfter.toStringAsFixed(2)}\n'
                                      'Ref: ${l['referenceKey'] ?? '-'} • ${l['createdAt'] != null ? DateFormat.yMMMd().add_jm().format(DateTime.parse(l['createdAt'])) : '-'}',
                                    ),
                                  ),
                                );
                              },
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Corporate Accounts & Credit Governance'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('New Account'),
            onPressed: _openCreateAccountDialog,
          ),
          const Gap(16),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search corporate accounts by company name or code...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _fetchAccounts(),
                  ),
                ),
                const Gap(12),
                ElevatedButton(
                  onPressed: _fetchAccounts,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Main Account List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _accounts.isEmpty
                        ? const Center(child: Text('No corporate accounts found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _accounts.length,
                            separatorBuilder: (_, __) => const Gap(8),
                            itemBuilder: (ctx, idx) {
                              final acc = _accounts[idx] as Map<String, dynamic>;
                              final creditLimit = double.tryParse(acc['creditLimit']?.toString() ?? '0') ?? 0.0;
                              final usedCredit = double.tryParse(acc['usedCredit']?.toString() ?? '0') ?? 0.0;
                              final available = creditLimit - usedCredit;
                              final isActive = acc['isActive'] == true;

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: ListTile(
                                  onTap: () => _inspectAccount(acc),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                    child: const Icon(Icons.business, color: Colors.blue),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        acc['companyName']?.toString() ?? '-',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isActive ? 'ACTIVE' : 'SUSPENDED',
                                          style: TextStyle(
                                            color: isActive ? Colors.green[800] : Colors.red[800],
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Code: ${acc['corporateCode']} • Discount: ${acc['negotiatedDiscountPct'] ?? 0}%\n'
                                    'Limit: ₹${creditLimit.toStringAsFixed(0)} • Used: ₹${usedCredit.toStringAsFixed(0)} • Available: ₹${available.toStringAsFixed(0)}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
