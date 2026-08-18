import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../providers/admin_coupons_providers.dart';

class AdminCouponsPage extends ConsumerWidget {
  const AdminCouponsPage({super.key});

  void _showCouponForm(BuildContext context, WidgetRef ref, [CouponModel? coupon]) {
    AppBottomSheet.show(
      context,
      title: coupon == null ? 'Create Coupon' : 'Edit Coupon',
      child: _CouponFormModal(
        couponToEdit: coupon,
        onSave: (Map<String, dynamic> data) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            if (coupon == null) {
              await ref.read(adminCouponsProvider.notifier).createCoupon(data);
              messenger.showSnackBar(
                const SnackBar(content: Text('Coupon created successfully!'), backgroundColor: Colors.green),
              );
            } else {
              await ref.read(adminCouponsProvider.notifier).updateCoupon(coupon.id, data);
              messenger.showSnackBar(
                const SnackBar(content: Text('Coupon updated successfully!'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to save coupon: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteCoupon(BuildContext context, WidgetRef ref, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Coupon'),
          content: Text('Are you sure you want to delete promo code "${coupon.code}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(adminCouponsProvider.notifier).deleteCoupon(coupon.id);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Coupon deleted successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete coupon: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(adminCouponsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coupon & Promo Code Management',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Gap(4),
                    Text(
                      'Configure discount codes, usage caps, minimum booking thresholds, and promotional restrictions.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Create Coupon',
                  isFullWidth: false,
                  onPressed: () => _showCouponForm(context, ref),
                ),
              ],
            ),
            const Gap(24),
            Expanded(
              child: couponsAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading coupons',
                  onRetry: () => ref.invalidate(adminCouponsProvider),
                ),
                data: (coupons) {
                  if (coupons.isEmpty) {
                    return AppCard(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_offer_outlined, size: 48, color: Colors.grey),
                            const Gap(12),
                            const Text('No coupons found', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Gap(4),
                            const Text('Click "Create Coupon" above to add your first promotional discount code.',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const Gap(16),
                            AppButton(
                              text: 'Create Coupon',
                              isFullWidth: false,
                              onPressed: () => _showCouponForm(context, ref),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AppCard(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Discount', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Limits & Caps', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Usage Count', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: coupons.map((c) {
                          final discountStr = c.discountType == 'PERCENTAGE'
                              ? '${c.discountValue.toInt()}% OFF'
                              : '₹${c.discountValue.toInt()} OFF';
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (c.description != null && c.description!.isNotEmpty)
                                      Text(c.description!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  discountStr,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                                ),
                              ),
                              DataCell(
                                Text(
                                  'Min: ₹${c.minBookingAmount?.toInt() ?? 0} | Max Cap: ${c.maxDiscountAmount != null ? "₹${c.maxDiscountAmount!.toInt()}" : "None"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text('${c.usageCount} used'),
                              ),
                              DataCell(
                                StatusBadge(
                                  status: c.isActive ? 'Active' : 'Inactive',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit Coupon',
                                      onPressed: () => _showCouponForm(context, ref, c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      tooltip: 'Delete Coupon',
                                      onPressed: () => _confirmDeleteCoupon(context, ref, c),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponFormModal extends StatefulWidget {
  final CouponModel? couponToEdit;
  final Function(Map<String, dynamic> data) onSave;

  const _CouponFormModal({
    this.couponToEdit,
    required this.onSave,
  });

  @override
  State<_CouponFormModal> createState() => _CouponFormModalState();
}

class _CouponFormModalState extends State<_CouponFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descController;
  late final TextEditingController _discountValController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _minBookingController;
  late final TextEditingController _globalLimitController;
  late final TextEditingController _perCustomerLimitController;
  late String _discountType;
  late bool _isActive;
  late bool _firstBookingOnly;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.couponToEdit?.code ?? '');
    _descController = TextEditingController(text: widget.couponToEdit?.description ?? '');
    _discountValController = TextEditingController(text: widget.couponToEdit?.discountValue.toString() ?? '');
    _maxDiscountController = TextEditingController(text: widget.couponToEdit?.maxDiscountAmount?.toString() ?? '');
    _minBookingController = TextEditingController(text: widget.couponToEdit?.minBookingAmount?.toString() ?? '');
    _globalLimitController = TextEditingController();
    _perCustomerLimitController = TextEditingController(text: '1');
    _discountType = widget.couponToEdit?.discountType ?? 'PERCENTAGE';
    _isActive = widget.couponToEdit?.isActive ?? true;
    _firstBookingOnly = widget.couponToEdit?.firstBookingOnly ?? false;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _discountValController.dispose();
    _maxDiscountController.dispose();
    _minBookingController.dispose();
    _globalLimitController.dispose();
    _perCustomerLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final payload = <String, dynamic>{
      'code': _codeController.text.trim().toUpperCase(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'discountType': _discountType,
      'discountValue': double.parse(_discountValController.text.trim()),
      'isActive': _isActive,
      'firstBookingOnly': _firstBookingOnly,
    };

    if (_maxDiscountController.text.trim().isNotEmpty) {
      payload['maxDiscountAmount'] = double.parse(_maxDiscountController.text.trim());
    }
    if (_minBookingController.text.trim().isNotEmpty) {
      payload['minBookingAmount'] = double.parse(_minBookingController.text.trim());
    }
    if (_globalLimitController.text.trim().isNotEmpty) {
      payload['globalUsageLimit'] = int.parse(_globalLimitController.text.trim());
    }
    if (_perCustomerLimitController.text.trim().isNotEmpty) {
      payload['perCustomerLimit'] = int.parse(_perCustomerLimitController.text.trim());
    }

    await widget.onSave(payload);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Coupon Code',
                controller: _codeController,
                hint: 'e.g. DRIVEGO20',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Code is required';
                  return null;
                },
              ),
              const Gap(12),
              AppTextField(
                label: 'Description',
                controller: _descController,
                hint: 'e.g. 20% off up to ₹500',
              ),
              const Gap(12),
              DropdownButtonFormField<String>(
                initialValue: _discountType,
                decoration: const InputDecoration(labelText: 'Discount Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'FIXED', child: Text('Fixed Amount (₹)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _discountType = val);
                },
              ),
              const Gap(12),
              AppTextField(
                label: 'Discount Value',
                controller: _discountValController,
                hint: _discountType == 'PERCENTAGE' ? 'e.g. 20' : 'e.g. 300',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Value is required';
                  if (double.tryParse(val.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Max Discount (₹)',
                      controller: _maxDiscountController,
                      hint: 'e.g. 500',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Min Booking (₹)',
                      controller: _minBookingController,
                      hint: 'e.g. 1000',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Global Limit',
                      controller: _globalLimitController,
                      hint: 'e.g. 100',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Per Customer Limit',
                      controller: _perCustomerLimitController,
                      hint: 'e.g. 1',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('First Booking Only'),
                value: _firstBookingOnly,
                onChanged: (val) => setState(() => _firstBookingOnly = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active Status'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const Gap(20),
              _isSaving
                  ? const Center(child: AppLoader())
                  : AppButton(
                      text: widget.couponToEdit == null ? 'Create Coupon' : 'Save Changes',
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
