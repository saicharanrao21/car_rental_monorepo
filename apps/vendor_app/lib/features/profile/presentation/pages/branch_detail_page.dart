import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../providers/branches_provider.dart';

class BranchDetailPage extends ConsumerWidget {
  final String branchId;

  const BranchDetailPage({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(vendorBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Profile'),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(child: Text('Error loading branch: $err')),
        data: (branches) {
          final branch = branches.firstWhere(
            (b) => b.id == branchId,
            orElse: () => throw Exception('Branch not found'),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.store_mall_directory_outlined, size: 36, color: AppColors.primary),
                      ),
                      const Gap(12),
                      Text(
                        branch.businessName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Gap(6),
                      StatusBadge(status: branch.verificationStatus.toLowerCase()),
                    ],
                  ),
                ),
                const Gap(24),

                // Info banner explaining read-only / future sub-account switching
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 22),
                      const Gap(12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branch Management Scope',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Gap(2),
                            Text(
                              'Branch context switching (managing fleet & bookings per branch) is coming soon in a future phase.',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                const SectionHeader(title: 'Branch Location Details'),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailRow(label: 'Branch Name', value: branch.businessName),
                        const Divider(height: 24),
                        _DetailRow(label: 'Manager Name', value: branch.ownerName),
                        const Divider(height: 24),
                        _DetailRow(label: 'City', value: branch.city),
                        const Divider(height: 24),
                        _DetailRow(label: 'Locality', value: branch.locality ?? 'Main Locality'),
                        const Divider(height: 24),
                        _DetailRow(
                          label: 'GPS Coordinates',
                          value: (branch.latitude != null && branch.longitude != null)
                              ? '${branch.latitude!.toStringAsFixed(4)}, ${branch.longitude!.toStringAsFixed(4)}'
                              : 'Not provided',
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          label: 'Created On',
                          value: DateFormat('dd MMM yyyy').format(branch.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(30),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }
}
