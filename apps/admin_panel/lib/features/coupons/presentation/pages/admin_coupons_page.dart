import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../../../../core/widgets/admin_data_grid.dart';
import '../providers/admin_coupons_providers.dart';

class AdminCouponsPage extends ConsumerStatefulWidget {
  const AdminCouponsPage({super.key});

  @override
  ConsumerState<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends ConsumerState<AdminCouponsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCouponForm(BuildContext context, WidgetRef ref, [CouponModel? coupon]) {
    AdminDetailDrawer.show(
      context: context,
      title: coupon == null ? 'Create Coupon' : 'Edit Coupon',
      subtitle: coupon != null ? 'Code: ${coupon.code}' : 'Configure promotional discount codes',
      child: _CouponFormModal(
        couponToEdit: coupon,
        onSave: (data) async {
          try {
            if (coupon == null) {
              await ref.read(adminCouponsProvider.notifier).createCoupon(data);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coupon created successfully!'), backgroundColor: Colors.green),
                );
              }
            } else {
              await ref.read(adminCouponsProvider.notifier).updateCoupon(coupon.id, data);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coupon updated successfully!'), backgroundColor: Colors.green),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save coupon: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDeleteCoupon(BuildContext context, WidgetRef ref, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Are you sure you want to delete promo code "${coupon.code}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminCouponsProvider.notifier).deleteCoupon(coupon.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coupon deleted successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete coupon: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleCouponStatus(BuildContext context, WidgetRef ref, CouponModel coupon) async {
    try {
      final newStatus = !coupon.isActive;
      await ref.read(adminCouponsProvider.notifier).toggleStatus(coupon.id, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon ${coupon.code} is now ${newStatus ? "Active" : "Inactive"}'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCouponUsagesDialog(BuildContext context, WidgetRef ref, CouponModel coupon) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history, color: Color(0xFF2563EB), size: 24),
                        ),
                        const Gap(12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Redemption History: ${coupon.code}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Total Usages: ${coupon.usageCount} redemptions',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ref.read(adminCouponsProvider.notifier).fetchCouponUsages(coupon.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: AppLoader());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading redemptions: ${snapshot.error}'));
                      }
                      final data = snapshot.data ?? {};
                      final usages = (data['usages'] as List<dynamic>?) ?? [];

                      if (usages.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                              Gap(12),
                              Text('No redemptions yet for this coupon code.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

                      return ListView.separated(
                        itemCount: usages.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final u = usages[idx] as Map<String, dynamic>;
                          final usedAt = u['usedAt'] != null
                              ? dateFormat.format(DateTime.parse(u['usedAt'].toString()))
                              : 'N/A';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withValues(alpha: 0.1),
                              child: const Icon(Icons.check, color: Colors.green, size: 18),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  u['customerName']?.toString() ?? 'Customer',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Gap(8),
                                if (u['customerPhone'] != null)
                                  Text(
                                    '(${u['customerPhone']})',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'Booking: ${u['bookingId']} • Car: ${u['carName']} • $usedAt',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Text(
                              '-₹${u['discountAmount']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 14),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Expanded(
                  child: Column(
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
                ),
                const Gap(16),
                AppButton(
                  text: 'Create Coupon',
                  isFullWidth: false,
                  onPressed: () => _showCouponForm(context, ref),
                ),
              ],
            ),
            const Gap(16),

            // Search & Filter Bar
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by promo code or description...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Gap(8),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _statusFilter == 'ALL',
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'ALL');
                        },
                      ),
                      const Gap(6),
                      ChoiceChip(
                        label: const Text('Active'),
                        selected: _statusFilter == 'ACTIVE',
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'ACTIVE');
                        },
                      ),
                      const Gap(6),
                      ChoiceChip(
                        label: const Text('Inactive'),
                        selected: _statusFilter == 'INACTIVE',
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = 'INACTIVE');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),

            Expanded(
              child: couponsAsync.when(
                loading: () => const AdminTableSkeleton(),
                error: (err, _) => AdminErrorState(
                  message: 'Error loading coupons: $err',
                  onRetry: () => ref.invalidate(adminCouponsProvider),
                ),
                data: (coupons) {
                  final query = _searchController.text.trim().toLowerCase();
                  final filteredCoupons = coupons.where((c) {
                    if (_statusFilter == 'ACTIVE' && !c.isActive) return false;
                    if (_statusFilter == 'INACTIVE' && c.isActive) return false;
                    if (query.isNotEmpty) {
                      final matchesCode = c.code.toLowerCase().contains(query);
                      final matchesDesc = c.description?.toLowerCase().contains(query) ?? false;
                      if (!matchesCode && !matchesDesc) return false;
                    }
                    return true;
                  }).toList();

                  return AdminDataGrid<CouponModel>(
                    items: filteredCoupons,
                    emptyTitle: 'No Coupons Found',
                    emptyMessage: 'No coupons matched your current search or filter criteria.',
                    emptyIcon: Icons.local_offer_outlined,
                    onRowTap: (c) => _showCouponForm(context, ref, c),
                    columns: [
                      AdminDataColumn(
                        title: 'PROMO CODE',
                        builder: (c) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            if (c.description != null && c.description!.isNotEmpty)
                              Text(c.description!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      AdminDataColumn(
                        title: 'DISCOUNT',
                        builder: (c) {
                          final discountStr = c.discountType == 'PERCENTAGE'
                              ? '${c.discountValue.toInt()}% OFF'
                              : '₹${c.discountValue.toInt()} OFF';
                          return Text(
                            discountStr,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          );
                        },
                      ),
                      AdminDataColumn(
                        title: 'LIMITS & CAPS',
                        builder: (c) => Text(
                          'Min: ₹${c.minBookingAmount?.toInt() ?? 0} | Max Cap: ${c.maxDiscountAmount != null ? "₹${c.maxDiscountAmount!.toInt()}" : "None"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      AdminDataColumn(
                        title: 'USAGE COUNT',
                        numeric: true,
                        builder: (c) => InkWell(
                          onTap: () => _showCouponUsagesDialog(context, ref, c),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${c.usageCount} used', style: const TextStyle(fontSize: 12.5, decoration: TextDecoration.underline, color: Color(0xFF2563EB))),
                              const Gap(4),
                              const Icon(Icons.open_in_new, size: 12, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      ),
                      AdminDataColumn(
                        title: 'STATUS',
                        builder: (c) => InkWell(
                          onTap: () => _toggleCouponStatus(context, ref, c),
                          child: AdminStatusBadge(status: c.isActive ? 'ACTIVE' : 'INACTIVE'),
                        ),
                      ),
                      AdminDataColumn(
                        title: 'ACTIONS',
                        builder: (c) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history_outlined, size: 18, color: Color(0xFF2563EB)),
                              tooltip: 'View Redemptions',
                              onPressed: () => _showCouponUsagesDialog(context, ref, c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Coupon',
                              onPressed: () => _showCouponForm(context, ref, c),
                            ),
                            IconButton(
                              icon: Icon(
                                c.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                size: 18,
                                color: c.isActive ? Colors.orange : Colors.green,
                              ),
                              tooltip: c.isActive ? 'Deactivate' : 'Activate',
                              onPressed: () => _toggleCouponStatus(context, ref, c),
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
                    mobileCardBuilder: (ctx, c) {
                      final discountStr = c.discountType == 'PERCENTAGE'
                          ? '${c.discountValue.toInt()}% OFF'
                          : '₹${c.discountValue.toInt()} OFF';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 14)),
                                AdminStatusBadge(status: c.isActive ? 'ACTIVE' : 'INACTIVE', compact: true),
                              ],
                            ),
                            const Gap(4),
                            Text('$discountStr • ${c.usageCount} redemptions', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
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
                hint: 'e.g. SUMMER2026',
                validator: (val) => val == null || val.trim().isEmpty ? 'Code is required' : null,
              ),
              const Gap(12),
              AppTextField(
                label: 'Description',
                controller: _descController,
                hint: 'e.g. 20% off up to ₹1,000 for holiday bookings',
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _discountType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Discount Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (%)')),
                        DropdownMenuItem(value: 'FIXED', child: Text('Fixed Amount (₹)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _discountType = val);
                      },
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: _discountType == 'PERCENTAGE' ? 'Discount (%)' : 'Discount (₹)',
                      controller: _discountValController,
                      hint: _discountType == 'PERCENTAGE' ? 'e.g. 20' : 'e.g. 500',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Value required';
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) return 'Must be > 0';
                        if (_discountType == 'PERCENTAGE' && num > 100) return 'Max 100%';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Max Discount (₹)',
                      controller: _maxDiscountController,
                      hint: 'Optional cap (e.g. 1000)',
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
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('First Booking Only'),
                  value: _firstBookingOnly,
                  onChanged: (val) => setState(() => _firstBookingOnly = val),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Status'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
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
