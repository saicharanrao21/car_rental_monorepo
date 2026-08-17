import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/api_providers.dart';

final pendingKycProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get('/admin/kyc/pending');
  return response.data as List<dynamic>;
});

class AdminKycPage extends ConsumerWidget {
  const AdminKycPage({super.key});

  Future<void> _reviewKyc(
    BuildContext context,
    WidgetRef ref,
    String kycId,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.patch('/admin/kyc/$kycId/review', data: {
        'status': status,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC successfully ${status == "VERIFIED" ? "approved" : "rejected"}!'),
            backgroundColor: status == 'VERIFIED' ? Colors.green : Colors.orange,
          ),
        );
        ref.invalidate(pendingKycProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reviewing KYC: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String kycId) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Driving Licence KYC'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please specify a rejection reason for the customer:'),
              const Gap(12),
              AppTextField(
                label: 'Rejection Reason',
                hint: 'e.g. Licence image blurry / Expired licence',
                controller: reasonCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Rejection reason is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _reviewKyc(context, ref, kycId, 'REJECTED', rejectionReason: reasonCtrl.text.trim());
              }
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingKycProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Document Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingKycProvider),
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading pending KYC: $err')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  Gap(16),
                  Text('No pending KYC submissions to review!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Gap(16),
            itemBuilder: (context, index) {
              final kyc = list[index] as Map<String, dynamic>;
              final user = kyc['user'] as Map<String, dynamic>? ?? {};

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(user['name'] ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text('PENDING REVIEW', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Text('Phone: ${user['phone'] ?? 'N/A'} | Email: ${user['email'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const Gap(8),
                    Text('Licence No: ${kyc['licenceNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Expiry Date: ${kyc['expiryDate'] != null ? kyc['expiryDate'].toString().split('T')[0] : 'N/A'}', style: const TextStyle(fontSize: 12)),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.image, size: 16),
                            label: const Text('Front Image', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _showImageDialog(context, 'Licence Front', kyc['licenceFrontUrl']);
                            },
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.image, size: 16),
                            label: const Text('Back Image', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _showImageDialog(context, 'Licence Back', kyc['licenceBackUrl']);
                            },
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () => _showRejectDialog(context, ref, kyc['id']),
                            child: const Text('Reject'),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _reviewKyc(context, ref, kyc['id'], 'VERIFIED'),
                            child: const Text('Approve KYC'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showImageDialog(BuildContext context, String title, String? imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: imageUrl != null && imageUrl.startsWith('http')
            ? Image.network(imageUrl, errorBuilder: (_, __, ___) => Text('Url: $imageUrl'))
            : Text('Image URL: ${imageUrl ?? "None"}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
