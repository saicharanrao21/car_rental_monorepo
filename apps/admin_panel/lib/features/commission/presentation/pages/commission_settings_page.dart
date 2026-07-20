import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../providers/commission_providers.dart';

class CommissionSettingsPage extends ConsumerStatefulWidget {
  const CommissionSettingsPage({super.key});

  @override
  ConsumerState<CommissionSettingsPage> createState() => _CommissionSettingsPageState();
}

class _CommissionSettingsPageState extends ConsumerState<CommissionSettingsPage> {
  // Calculator Form State
  final _calcFareController = TextEditingController(text: '1000');
  String _calcCity = 'All';
  String _calcCategory = 'All';
  String _calcTripType = 'All';

  // Calculator Result
  FareCalculatorResult? _calcResult;
  double? _calcMatchedRate;
  String? _calcMatchedRuleDesc;

  @override
  void dispose() {
    _calcFareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(commissionRulesProvider);

    // Show errors if controller operation fails
    ref.listen<AsyncValue<void>>(commissionControllerProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commission Settings',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Gap(4),
                    Text(
                      'Manage platform commission configurations and preview splits',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Add Commission Rule',
                  isFullWidth: false,
                  onPressed: () => _showRuleForm(context),
                ),
              ],
            ),
            const Gap(24),

            // Content body
            Expanded(
              child: rulesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading commission rules',
                  onRetry: () => ref.invalidate(commissionRulesProvider),
                ),
                data: (rules) {
                  if (rules.isEmpty) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: EmptyStateWidget(
                            icon: Icons.percent_outlined,
                            title: 'No Rules Configured',
                            subtitle: 'Add a commission rule to get started.',
                            onActionPressed: () => _showRuleForm(context),
                            actionText: 'Add Rule',
                          ),
                        ),
                        const Gap(24),
                        Expanded(
                          flex: 2,
                          child: _buildCalculatorAndActions(context, rules),
                        ),
                      ],
                    );
                  }

                  if (Responsive.isDesktop(context)) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildRulesTableCard(context, rules),
                        ),
                        const Gap(24),
                        Expanded(
                          flex: 2,
                          child: _buildCalculatorAndActions(context, rules),
                        ),
                      ],
                    );
                  } else {
                    return _buildVerticalLayout(context, rules);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context, List<CommissionConfigModel> rules) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRulesTableCard(context, rules),
          const Gap(24),
          _buildCalculatorAndActions(context, rules),
        ],
      ),
    );
  }

  Widget _buildRulesTableCard(BuildContext context, List<CommissionConfigModel> rules) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Commission Rules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Applies To Scope')),
                  DataColumn(label: Text('Commission %', textAlign: TextAlign.right)),
                  DataColumn(label: Text('Effective From')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rules.map((rule) {
                  final scopeLabel = _formatAppliesTo(rule);
                  final formattedDate = DateFormat('dd MMM yyyy').format(rule.effectiveFrom);

                  return DataRow(
                    cells: [
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            scopeLabel,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          alignment: Alignment.centerRight,
                          width: 80,
                          child: Text(
                            '${rule.percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(Text(formattedDate)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              tooltip: 'Edit Rule',
                              onPressed: () => _showRuleForm(context, rule),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              tooltip: 'Delete Rule',
                              onPressed: () => _confirmDeleteRule(context, rule),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorAndActions(BuildContext context, List<CommissionConfigModel> rules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview Calculator Card
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Commission Preview Calculator',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Gap(4),
              Text(
                'Estimate fare details and commission shares based on rule matching.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Gap(20),

              // Base Fare Input
              AppTextField(
                label: 'Base Fare Amount (₹)',
                controller: _calcFareController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: 'e.g. 1000',
              ),
              const Gap(16),

              // City Selector
              AppDropdown<String>(
                label: 'City Scope',
                value: _calcCity,
                items: ['All', ...AppConstants.indianCities].map((city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: SizedBox(
                      width: 140,
                      child: Text(city, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _calcCity = val ?? 'All';
                  });
                },
              ),
              const Gap(16),

              // Category Selector
              AppDropdown<String>(
                label: 'Car Category Scope',
                value: _calcCategory,
                items: ['All', ...AppConstants.carCategories].map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: SizedBox(
                      width: 140,
                      child: Text(cat, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _calcCategory = val ?? 'All';
                  });
                },
              ),
              const Gap(16),

              // Trip Type Selector
              AppDropdown<String>(
                label: 'Trip Type Scope',
                value: _calcTripType,
                items: ['All', ...AppConstants.tripTypes].map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: SizedBox(
                      width: 140,
                      child: Text(type, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _calcTripType = val ?? 'All';
                  });
                },
              ),
              const Gap(20),

              AppButton(
                text: 'Calculate Fare Split',
                onPressed: () => _calculatePreviewSplit(rules),
              ),

              if (_calcResult != null) ...[
                const Gap(24),
                const Divider(),
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Matched Commission rate:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${(_calcMatchedRate ?? 10.0).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  _calcMatchedRuleDesc ?? 'Using platform default commission (10.0%)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const Gap(16),
                _buildBreakdownItem('Base Fare (Vendor Payout)', _calcResult!.baseFare),
                _buildBreakdownItem('Platform Fee (Commission)', _calcResult!.platformFee),
                _buildBreakdownItem('GST (18% on platform fee)', _calcResult!.gst),
                const Gap(8),
                const Divider(),
                const Gap(8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Customer Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    PriceTag(
                      amount: _calcResult!.total,
                      amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatAppliesTo(CommissionConfigModel rule) {
    final city = (rule.city == 'All' || rule.city.isEmpty) ? 'All Cities' : rule.city;
    final cat = (rule.carCategory == 'All' || rule.carCategory.isEmpty) ? 'All Categories' : rule.carCategory;
    final type = (rule.tripType == 'All' || rule.tripType.isEmpty) ? 'All Trip Types' : rule.tripType;
    return '$city | $cat | $type';
  }

  void _calculatePreviewSplit(List<CommissionConfigModel> rules) {
    final fareInput = double.tryParse(_calcFareController.text) ?? 0.0;
    if (fareInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid base fare amount greater than 0')),
      );
      return;
    }

    // Match rule
    CommissionConfigModel? bestMatch;
    int bestScore = -1;

    for (final rule in rules) {
      final cityMatch = rule.city == 'All' || rule.city.isEmpty || rule.city.toLowerCase() == _calcCity.toLowerCase();
      final categoryMatch = rule.carCategory == 'All' || rule.carCategory.isEmpty || rule.carCategory.toLowerCase() == _calcCategory.toLowerCase();
      final tripTypeMatch = rule.tripType == 'All' || rule.tripType.isEmpty || rule.tripType.toLowerCase() == _calcTripType.toLowerCase();

      if (cityMatch && categoryMatch && tripTypeMatch) {
        int score = 0;
        if (rule.city != 'All' && rule.city.isNotEmpty) score += 4;
        if (rule.carCategory != 'All' && rule.carCategory.isNotEmpty) score += 2;
        if (rule.tripType != 'All' && rule.tripType.isNotEmpty) score += 1;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = rule;
        }
      }
    }

    final double rate = bestMatch?.percentage ?? 10.0;
    final String desc = bestMatch != null
        ? 'Matched Rule: ${_formatAppliesTo(bestMatch)}'
        : 'No specific rule matched. Defaulting to 10%';

    final result = FareCalculatorService.calculateFare(
      distanceKm: 0,
      basePackagePrice: fareInput,
      pricePerKm: 0,
      commissionPercent: rate,
    );

    setState(() {
      _calcResult = result;
      _calcMatchedRate = rate;
      _calcMatchedRuleDesc = desc;
    });
  }

  void _confirmDeleteRule(BuildContext context, CommissionConfigModel rule) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Commission Rule'),
          content: Text('Are you sure you want to delete the commission rule for "${_formatAppliesTo(rule)}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(commissionControllerProvider.notifier).deleteRule(rule.id);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showRuleForm(BuildContext context, [CommissionConfigModel? ruleToEdit]) {
    AppBottomSheet.show(
      context,
      title: ruleToEdit == null ? 'Add Commission Rule' : 'Edit Commission Rule',
      child: _RuleFormModal(
        ruleToEdit: ruleToEdit,
        onSave: (rule) {
          if (ruleToEdit == null) {
            ref.read(commissionControllerProvider.notifier).addRule(rule);
          } else {
            ref.read(commissionControllerProvider.notifier).updateRule(rule);
          }
        },
      ),
    );
  }
}

class _RuleFormModal extends StatefulWidget {
  final CommissionConfigModel? ruleToEdit;
  final ValueChanged<CommissionConfigModel> onSave;

  const _RuleFormModal({
    this.ruleToEdit,
    required this.onSave,
  });

  @override
  State<_RuleFormModal> createState() => _RuleFormModalState();
}

class _RuleFormModalState extends State<_RuleFormModal> {
  final _formKey = GlobalKey<FormState>();
  late String _city;
  late String _carCategory;
  late String _tripType;
  late TextEditingController _percentController;
  late DateTime _effectiveFrom;

  @override
  void initState() {
    super.initState();
    _city = widget.ruleToEdit?.city ?? 'All';
    _carCategory = widget.ruleToEdit?.carCategory ?? 'All';
    _tripType = widget.ruleToEdit?.tripType ?? 'All';
    _percentController = TextEditingController(
      text: widget.ruleToEdit?.percentage.toString() ?? '10.0',
    );
    _effectiveFrom = widget.ruleToEdit?.effectiveFrom ?? DateTime.now();
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scope Fields Row/Wrap
            AppDropdown<String>(
              label: 'City Scope',
              value: _city,
              items: ['All', ...AppConstants.indianCities].map((city) {
                return DropdownMenuItem<String>(
                  value: city,
                  child: SizedBox(
                    width: 150,
                    child: Text(city, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _city = val ?? 'All';
                });
              },
            ),
            const Gap(16),

            AppDropdown<String>(
              label: 'Car Category Scope',
              value: _carCategory,
              items: ['All', ...AppConstants.carCategories].map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: SizedBox(
                    width: 150,
                    child: Text(cat, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _carCategory = val ?? 'All';
                });
              },
            ),
            const Gap(16),

            AppDropdown<String>(
              label: 'Trip Type Scope',
              value: _tripType,
              items: ['All', ...AppConstants.tripTypes].map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: SizedBox(
                    width: 150,
                    child: Text(type, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _tripType = val ?? 'All';
                });
              },
            ),
            const Gap(16),

            // Commission Percent Input
            AppTextField(
              label: 'Commission Percentage (%)',
              controller: _percentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              hint: 'e.g. 12.5',
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a percentage';
                }
                final num = double.tryParse(val);
                if (num == null || num < 0 || num > 100) {
                  return 'Enter a value between 0 and 100';
                }
                return null;
              },
            ),
            const Gap(16),

            // Effective From Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _effectiveFrom,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _effectiveFrom = date;
                  });
                }
              },
              child: IgnorePointer(
                child: AppTextField(
                  label: 'Effective From Date',
                  controller: TextEditingController(
                    text: DateFormat('dd MMM yyyy').format(_effectiveFrom),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
              ),
            ),
            const Gap(24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: AppButton(
                    text: widget.ruleToEdit == null ? 'Create Config' : 'Save Changes',
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final rate = double.parse(_percentController.text);
                        final rule = CommissionConfigModel(
                          id: widget.ruleToEdit?.id ?? 'cc_${DateTime.now().millisecondsSinceEpoch}',
                          city: _city,
                          carCategory: _carCategory,
                          tripType: _tripType,
                          percentage: rate,
                          effectiveFrom: _effectiveFrom,
                        );
                        widget.onSave(rule);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
