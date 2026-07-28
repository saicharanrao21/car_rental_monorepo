import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../providers/branches_provider.dart';

class VendorBranchesPage extends ConsumerWidget {
  const VendorBranchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(vendorBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Branches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Branch',
            onPressed: () => context.push('/branches/add'),
          ),
        ],
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: AppLoader()),
        error: (err, _) => Center(
          child: ErrorStateWidget(
            message: 'Failed to load branches: $err',
            onRetry: () => ref.invalidate(vendorBranchesProvider),
          ),
        ),
        data: (branches) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vendorBranchesProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location Branches',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/branches/add'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Branch'),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Manage branch locations under your main vendor account.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Gap(20),

                  if (branches.isEmpty) ...[
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.store_mall_directory_outlined, size: 48, color: Colors.grey),
                            const Gap(12),
                            const Text(
                              'No branches added yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Gap(4),
                            Text(
                              'Expand your operations by adding location branches in other cities or areas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const Gap(16),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/branches/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Branch'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: branches.length,
                      separatorBuilder: (context, index) => const Gap(12),
                      itemBuilder: (context, index) {
                        final branch = branches[index];
                        return AppCard(
                          onTap: () => context.push('/branches/${branch.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        branch.businessName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    StatusBadge(status: branch.verificationStatus.toLowerCase()),
                                  ],
                                ),
                                const Gap(8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                    const Gap(4),
                                    Text(
                                      '${branch.locality ?? 'Main Locality'}, ${branch.city}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                if (branch.latitude != null && branch.longitude != null) ...[
                                  const Gap(4),
                                  Text(
                                    'GPS: ${branch.latitude!.toStringAsFixed(4)}, ${branch.longitude!.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                                const Gap(12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Manager: ${branch.ownerName}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const Row(
                                      children: [
                                        Text('View Details', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        Gap(4),
                                        Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const Gap(30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
