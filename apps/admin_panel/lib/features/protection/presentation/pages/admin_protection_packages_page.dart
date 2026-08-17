import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../../../../core/providers/api_providers.dart';

final adminProtectionPackagesProvider =
    FutureProvider.autoDispose<List<ProtectionPackageModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/protection-packages');
  final list = response.data as List<dynamic>;
  return list.map((e) => ProtectionPackageModel.fromJson(e as Map<String, dynamic>)).toList();
});

class AdminProtectionPackagesPage extends ConsumerStatefulWidget {
  const AdminProtectionPackagesPage({super.key});

  @override
  ConsumerState<AdminProtectionPackagesPage> createState() =>
      _AdminProtectionPackagesPageState();
}

class _AdminProtectionPackagesPageState extends ConsumerState<AdminProtectionPackagesPage> {
  void _openEditPackageDialog(ProtectionPackageModel pkg) {
    final dailyRateCtrl = TextEditingController(text: pkg.dailyRate.toString());
    final deductibleCtrl = TextEditingController(text: pkg.deductibleAmount.toString());
    bool isActive = pkg.isActive;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Protection Package: ${pkg.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dailyRateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Daily Fee (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const Gap(16),
              TextField(
                controller: deductibleCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Customer Deductible (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const Gap(16),
              SwitchListTile(
                title: const Text('Active for Bookings'),
                value: isActive,
                onChanged: (val) => setModalState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        await apiClient.dio.patch(
                          '/protection-packages/${pkg.id}',
                          data: {
                            'dailyRate': double.tryParse(dailyRateCtrl.text.trim()) ?? pkg.dailyRate,
                            'deductibleAmount': double.tryParse(deductibleCtrl.text.trim()) ?? pkg.deductibleAmount,
                            'isActive': isActive,
                          },
                        );
                        ref.invalidate(adminProtectionPackagesProvider);
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating package: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(adminProtectionPackagesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.blue, size: 28),
                        Gap(10),
                        Text('Protection & Insurance Packages',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Gap(4),
                    Text('Configure customer damage liability coverage tiers, daily add-on rates, and deductibles.',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: () => ref.invalidate(adminProtectionPackagesProvider),
                ),
              ],
            ),
            const Gap(24),

            Expanded(
              child: packagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading protection packages: $err',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (packages) {
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: pkg.isActive ? Colors.blue.shade200 : Colors.grey.shade300,
                            width: pkg.isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pkg.code.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.blue.shade800),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: pkg.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pkg.isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: pkg.isActive ? Colors.green.shade800 : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(12),
                              Text(
                                pkg.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Gap(4),
                              Text(
                                pkg.description,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Gap(16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Daily Fee',
                                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text('₹${pkg.dailyRate.toInt()} / day',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Max Deductible',
                                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                          pkg.deductibleAmount == 0
                                              ? '₹0 (Zero Dep)'
                                              : '₹${pkg.deductibleAmount.toInt()}',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal)),
                                    ],
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Divider(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit Package'),
                                  onPressed: () => _openEditPackageDialog(pkg),
                                ),
                              ),
                            ],
                          ),
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
