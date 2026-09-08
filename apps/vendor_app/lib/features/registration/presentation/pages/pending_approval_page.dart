import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../domain/models/vendor_compliance_models.dart';
import '../providers/vendor_compliance_providers.dart';

class PendingApprovalPage extends ConsumerStatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  ConsumerState<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends ConsumerState<PendingApprovalPage> {
  @override
  Widget build(BuildContext context) {
    final eligibilityAsync = ref.watch(vendorEligibilityProvider);
    final requirementsAsync = ref.watch(vendorRequirementsProvider);
    final depositAsync = ref.watch(vendorDepositSummaryProvider);
    final controllerState = ref.watch(vendorComplianceControllerProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Onboarding Compliance & Deposits',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(vendorComplianceControllerProvider.notifier).refreshAll();
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.read(vendorComplianceControllerProvider.notifier).refreshAll();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Overall Compliance Status Banner
                  _buildComplianceStatusCard(eligibilityAsync, requirementsAsync),
                  const Gap(20),

                  // 2. Next Actions Card
                  _buildNextActionsCard(eligibilityAsync, depositAsync),
                  const Gap(20),

                  // 3. Security Deposit Card
                  _buildDepositCard(context, depositAsync),
                  const Gap(20),

                  // 4. Service Area Coverage Status
                  _buildServiceAreaCard(eligibilityAsync),
                  const Gap(20),

                  // 5. Dynamic Requirements List
                  _buildRequirementsSection(context, requirementsAsync),
                  const Gap(32),

                  // 6. Footer Actions
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support helpline: support@drivego.in | +91 80000 12345'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline, color: AppColors.primary),
                      label: const Text(
                        'Need help with compliance? Contact Partner Desk',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Gap(16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    icon: const Icon(Icons.exit_to_app, color: Colors.grey),
                    label: const Text(
                      'Logout & Complete Later',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _handleLogout(context, ref),
                  ),
                  const Gap(40),
                ],
              ),
            ),
          ),
          if (controllerState.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    ref.read(vendorSessionProvider.notifier).logout();
    context.go('/auth/phone');
  }

  Widget _buildComplianceStatusCard(
    AsyncValue<VendorEligibilityModel> eligibilityAsync,
    AsyncValue<List<VendorRequirementItemModel>> requirementsAsync,
  ) {
    return eligibilityAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const Gap(16),
            Expanded(
              child: Text(
                'Unable to evaluate onboarding compliance: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
      data: (eligibility) {
        final requirements = requirementsAsync.asData?.value ?? [];
        final hasPending = requirements.any((r) => r.state == 'PENDING');
        final isRejected = eligibility.verificationStatus == 'REJECTED' ||
            requirements.any((r) => r.state == 'REJECTED');

        String statusLabel;
        Color statusColor;
        IconData statusIcon;
        String statusDesc;

        if (eligibility.isEligible) {
          statusLabel = 'Approved';
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusDesc =
              'All compliance requirements and security deposits are verified. Your vendor account is approved!';
        } else if (isRejected) {
          statusLabel = 'Blocked';
          statusColor = Colors.red;
          statusIcon = Icons.cancel_outlined;
          statusDesc =
              'One or more submissions were rejected or require corrections. Please review the items below.';
        } else if (hasPending) {
          statusLabel = 'Under Review';
          statusColor = Colors.amber[800]!;
          statusIcon = Icons.hourglass_top_outlined;
          statusDesc =
              'Your compliance documents have been submitted and are being reviewed by platform administrators.';
        } else {
          statusLabel = 'Incomplete';
          statusColor = Colors.orange;
          statusIcon = Icons.assignment_late_outlined;
          statusDesc =
              'Action required: please submit all mandatory onboarding documents and security deposit to activate your account.';
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 30),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Compliance Status',
                          style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(14),
              Text(
                statusDesc,
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
              ),
              if (eligibility.blockers.isNotEmpty) ...[
                const Gap(12),
                const Divider(),
                const Gap(8),
                const Text(
                  'Activation Blockers:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const Gap(6),
                ...eligibility.blockers.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right, size: 18, color: Colors.red),
                        Expanded(
                          child: Text(
                            b,
                            style: const TextStyle(fontSize: 13, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNextActionsCard(
    AsyncValue<VendorEligibilityModel> eligibilityAsync,
    AsyncValue<VendorDepositSummaryModel> depositAsync,
  ) {
    final eligibility = eligibilityAsync.asData?.value;
    final deposit = depositAsync.asData?.value;

    final nextActions = <String>[];
    if (eligibility != null) {
      if (!eligibility.requirementsSatisfied) {
        if (eligibility.missingMandatoryRequirements.isNotEmpty) {
          nextActions.add(
              'Submit mandatory requirements: ${eligibility.missingMandatoryRequirements.join(', ')}');
        } else {
          nextActions.add('Review and fulfill remaining pending requirements.');
        }
      }
      if (!eligibility.securityDepositSatisfied && deposit != null) {
        nextActions.add(
            'Deposit required: Pay remaining ₹${deposit.remainingAmount.toStringAsFixed(0)} (Min initial: ₹${deposit.minInitialAmount.toStringAsFixed(0)}).');
      }
      if (!eligibility.serviceAreaEligible) {
        nextActions.add('Assign service area coverage or await administrator zone authorization.');
      }
      if (nextActions.isEmpty && !eligibility.isEligible) {
        nextActions.add('Awaiting final administrator review and profile verification.');
      }
    }

    if (nextActions.isEmpty && (eligibility?.isEligible ?? false)) {
      nextActions.add('All checks passed! You may now proceed to manage your fleet and branches.');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      color: Colors.blue[50]?.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_run_outlined, color: Colors.blue, size: 22),
                Gap(8),
                Text(
                  'Next Steps for Onboarding',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Gap(10),
            if (nextActions.isEmpty)
              const Text('Evaluating onboarding requirements...', style: TextStyle(fontSize: 13))
            else
              ...nextActions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositCard(
    BuildContext context,
    AsyncValue<VendorDepositSummaryModel> depositAsync,
  ) {
    return depositAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Deposit information unavailable: $err'),
        ),
      ),
      data: (deposit) {
        Color statusColor;
        switch (deposit.status) {
          case 'PAID':
            statusColor = Colors.green;
            break;
          case 'PARTIALLY_PAID':
            statusColor = Colors.blue;
            break;
          case 'HELD':
            statusColor = Colors.deepOrange;
            break;
          case 'FORFEITED':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.amber[800]!;
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                        ),
                        const Gap(10),
                        const Text(
                          'Security Deposit',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        deposit.status.replaceAll('_', ' '),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Required', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Gap(4),
                            Text(
                              '₹${deposit.requiredAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Gap(4),
                            Text(
                              '₹${deposit.paidAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const Gap(4),
                            Text(
                              '₹${deposit.remainingAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: deposit.remainingAmount > 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(14),
                Text(
                  deposit.allowPartialPayment
                      ? 'Note: Partial payments are permitted. Minimum initial deposit amount is ₹${deposit.minInitialAmount.toStringAsFixed(0)}.'
                      : 'Note: Full deposit of ₹${deposit.requiredAmount.toStringAsFixed(0)} must be paid in single transaction.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
                if (deposit.remainingAmount > 0) ...[
                  const Gap(16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.payment, size: 20),
                    label: Text(
                      'Pay Security Deposit (₹${deposit.remainingAmount.toStringAsFixed(0)})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showPaymentDialog(context, deposit),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceAreaCard(AsyncValue<VendorEligibilityModel> eligibilityAsync) {
    final eligibility = eligibilityAsync.asData?.value;
    final isEligible = eligibility?.serviceAreaEligible ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEligible ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEligible ? Icons.map : Icons.location_off,
                color: isEligible ? Colors.green : Colors.orange,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operational Service Area',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Gap(2),
                  Text(
                    isEligible
                        ? 'Authorized operational service area configured and verified.'
                        : 'Service area coverage pending configuration or authorization.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isEligible ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEligible ? 'Active' : 'Pending',
                style: TextStyle(
                  color: isEligible ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsSection(
    BuildContext context,
    AsyncValue<List<VendorRequirementItemModel>> requirementsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Compliance Requirements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${requirementsAsync.asData?.value.length ?? 0} Required Items',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const Gap(12),
        requirementsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(child: Text('Error loading requirements: $err')),
          data: (requirements) {
            if (requirements.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Text('No dynamic requirements currently defined by platform.'),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requirements.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (ctx, i) {
                final item = requirements[i];
                return _buildRequirementTile(ctx, item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequirementTile(BuildContext context, VendorRequirementItemModel item) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (item.state) {
      case 'VERIFIED':
        statusColor = Colors.green;
        statusLabel = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'PENDING':
        statusColor = Colors.amber[800]!;
        statusLabel = 'Under Review';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'EXPIRED':
        statusColor = Colors.purple;
        statusLabel = 'Expired';
        statusIcon = Icons.alarm;
        break;
      case 'WAIVED':
        statusColor = Colors.blue;
        statusLabel = 'Waived';
        statusIcon = Icons.verified;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'Missing';
        statusIcon = Icons.radio_button_unchecked;
    }

    final canSubmit = item.state == 'MISSING' || item.state == 'REJECTED' || item.state == 'EXPIRED';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.state == 'REJECTED' ? Colors.red.withValues(alpha: 0.4) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(fontSize: 10.5, color: Colors.grey[700]),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isRequired ? Colors.red[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isRequired ? 'Mandatory' : 'Optional',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: item.isRequired ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (item.serviceAreaName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.serviceAreaName!,
                              style: const TextStyle(fontSize: 10.5, color: Colors.purple),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
            const Gap(10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Admin Review: ${item.rejectionReason!}',
                      style: const TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canSubmit) ...[
            const Gap(12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(item.state == 'MISSING' ? 'Upload Document' : 'Re-submit Document'),
                onPressed: () => _showUploadDialog(context, item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context, VendorRequirementItemModel item) {
    final docUrlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upload: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requirement Category: ${item.category}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Gap(16),
            TextField(
              controller: docUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Document URL or Cloud Storage Link *',
                hintText: 'https://storage.drivego.in/docs/...',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Additional Notes / Document Details',
                hintText: 'e.g., Certificate registration number, expiry date',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final url = docUrlCtrl.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a document URL')),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(vendorComplianceControllerProvider.notifier)
                  .submitDocument(
                    definitionId: item.definitionId,
                    documentUrl: url,
                    metadata: notesCtrl.text.trim().isNotEmpty
                        ? {'notes': notesCtrl.text.trim(), 'uploadedAt': DateTime.now().toIso8601String()}
                        : {'uploadedAt': DateTime.now().toIso8601String()},
                  );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Document submitted successfully! Status updated to Under Review.'
                          : 'Failed to submit document. Please check and retry.',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit for Review'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, VendorDepositSummaryModel deposit) {
    final amountCtrl =
        TextEditingController(text: deposit.remainingAmount.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    String selectedMethod = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Text('Make Security Deposit Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remaining Deposit: ₹${deposit.remainingAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (deposit.allowPartialPayment)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Minimum Initial: ₹${deposit.minInitialAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  const Gap(16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount (₹) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Gap(14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                      DropdownMenuItem(value: 'NETBANKING', child: Text('Net Banking')),
                      DropdownMenuItem(value: 'CARD', child: Text('Debit / Credit Card')),
                      DropdownMenuItem(value: 'NEFT', child: Text('Bank Wire (NEFT / RTGS)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMethod = val);
                      }
                    },
                  ),
                  const Gap(14),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Reference / UTR Number',
                      hintText: 'e.g., UPI-TXN-98421045',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid payment amount')),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  final success = await ref
                      .read(vendorComplianceControllerProvider.notifier)
                      .payDeposit(
                        amount: amount,
                        paymentMethod: selectedMethod,
                        reference: refCtrl.text.trim(),
                      );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Security deposit payment of ₹${amount.toStringAsFixed(0)} recorded successfully!'
                              : 'Payment failed. Please verify amount and rules.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
