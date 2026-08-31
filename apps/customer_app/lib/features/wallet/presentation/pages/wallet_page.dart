import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/wallet_providers.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final _razorpay = Razorpay();
  bool _isProcessingDeposit = false;
  String? _pendingDepositOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleDepositSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleDepositError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handleDepositSuccess(PaymentSuccessResponse response) async {
    final orderId = _pendingDepositOrderId ?? response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification details incomplete.'),
            backgroundColor: DDSColors.errorRed,
          ),
        );
      }
      setState(() => _isProcessingDeposit = false);
      return;
    }

    try {
      final repo = ref.read(walletRepositoryProvider);
      await repo.verifyDeposit(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

      ref.invalidate(customerWalletProvider);
      ref.invalidate(customerWalletTransactionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funds added successfully to your DriveGo Wallet!'),
            backgroundColor: DDSColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deposit verification failed: $e'),
            backgroundColor: DDSColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingDeposit = false);
      }
    }
  }

  void _handleDepositError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment cancelled or failed: ${response.message}'),
          backgroundColor: DDSColors.warningOrange,
        ),
      );
      setState(() => _isProcessingDeposit = false);
    }
  }

  void _showAddMoneyBottomSheet(BuildContext context) {
    final amountController = TextEditingController(text: '1000');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + DDSSpacing.lg,
            left: DDSSpacing.lg,
            right: DDSSpacing.lg,
            top: DDSSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DDSColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(DDSSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Add Money to Wallet',
                        style: DDSTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DDSColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: DDSColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  'Enter amount (Min ₹100 - Max ₹50,000)',
                  style: DDSTypography.bodyMedium.copyWith(fontSize: 13, color: DDSColors.textMuted),
                ),
                const Gap(DDSSpacing.md),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Amount',
                    border: OutlineInputBorder(borderRadius: DDSRadius.mediumBorderRadius),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final num = double.tryParse(val.trim());
                    if (num == null || num < 100 || num > 50000) {
                      return 'Amount must be between ₹100 and ₹50,000';
                    }
                    return null;
                  },
                ),
                const Gap(DDSSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    _presetChip(amountController, 500),
                    _presetChip(amountController, 1000),
                    _presetChip(amountController, 2000),
                    _presetChip(amountController, 5000),
                  ],
                ),
                const Gap(DDSSpacing.xl),
                AppButton(
                  text: 'Proceed to Pay',
                  isLoading: _isProcessingDeposit,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amt = double.parse(amountController.text.trim());
                    Navigator.pop(ctx);

                    setState(() => _isProcessingDeposit = true);
                    try {
                      final repo = ref.read(walletRepositoryProvider);
                      final orderData = await repo.createDepositOrder(amt);
                      final orderId = orderData['orderId'] as String;
                      final keyId = orderData['keyId'] as String? ?? 'rzp_test_placeholderKeyId';
                      final isMock = orderData['isMock'] == true;

                      _pendingDepositOrderId = orderId;

                      if (isMock) {
                        // Mock fallback flow
                        _handleDepositSuccess(
                          PaymentSuccessResponse(
                            'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
                            orderId,
                            'mock_signature',
                            null,
                          ),
                        );
                      } else {
                        final options = {
                          'key': keyId,
                          'amount': (amt * 100).toInt(),
                          'name': 'DriveGo Wallet',
                          'description': 'Add Money to Wallet',
                          'order_id': orderId,
                          'currency': 'INR',
                          'prefill': {
                            'contact': '',
                            'email': '',
                          },
                        };
                        _razorpay.open(options);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to initiate deposit: $e'),
                          backgroundColor: DDSColors.errorRed,
                        ),
                      );
                      setState(() => _isProcessingDeposit = false);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _presetChip(TextEditingController ctrl, int amount) {
    return ActionChip(
      backgroundColor: DDSColors.infoBlueBg,
      side: BorderSide(color: DDSColors.primaryBlue.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: DDSRadius.smallBorderRadius),
      label: Text('+₹$amount', style: DDSTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: DDSColors.primaryBlue)),
      onPressed: () {
        ctrl.text = amount.toString();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(customerWalletProvider);
    final transactionsAsync = ref.watch(customerWalletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DriveGo Wallet',
          style: DDSTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: DDSColors.primaryBlue),
            tooltip: 'Refresh Balance',
            onPressed: () {
              ref.invalidate(customerWalletProvider);
              ref.invalidate(customerWalletTransactionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerWalletProvider);
          ref.invalidate(customerWalletTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DDSSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Card
              walletAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(DDSSpacing.md),
                  decoration: BoxDecoration(
                    color: DDSColors.surfaceCard,
                    borderRadius: DDSRadius.largeBorderRadius,
                    border: Border.all(color: DDSColors.borderLight),
                  ),
                  child: Text('Failed to load wallet: $err', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.errorRed)),
                ),
                data: (wallet) {
                  return Container(
                    padding: const EdgeInsets.all(DDSSpacing.lg),
                    decoration: BoxDecoration(
                      color: DDSColors.surfaceCard,
                      borderRadius: DDSRadius.largeBorderRadius,
                      border: Border.all(color: DDSColors.borderLight),
                      boxShadow: DDSElevation.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Available Balance',
                                style: DDSTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: DDSColors.textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: wallet.status == WalletStatus.ACTIVE
                                    ? DDSColors.successGreenBg
                                    : DDSColors.warningOrangeBg,
                                borderRadius: DDSRadius.smallBorderRadius,
                                border: Border.all(
                                  color: wallet.status == WalletStatus.ACTIVE
                                      ? DDSColors.successGreen.withValues(alpha: 0.3)
                                      : DDSColors.warningOrange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                wallet.status.name,
                                style: DDSTypography.labelSmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: wallet.status == WalletStatus.ACTIVE
                                      ? DDSColors.successGreen
                                      : DDSColors.warningOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        Text(
                          '₹${wallet.availableBalance.toStringAsFixed(2)}',
                          style: DDSTypography.displayLarge.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: DDSColors.primaryBlue,
                          ),
                        ),
                        const Gap(DDSSpacing.md),
                        const Divider(height: 1, color: DDSColors.borderLight),
                        const Gap(DDSSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _balanceChip(
                                label: 'Real Cash',
                                amount: wallet.realBalance,
                                icon: Icons.account_balance_wallet_outlined,
                                color: DDSColors.primaryBlue,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: _balanceChip(
                                label: 'Promo / Rewards',
                                amount: wallet.promoBalance,
                                icon: Icons.stars_outlined,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Gap(DDSSpacing.lg),
                        AppButton(
                          text: '+ Add Money',
                          onPressed: () => _showAddMoneyBottomSheet(context),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Gap(DDSSpacing.lg),
              Text(
                'Transaction History',
                style: DDSTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
              ),
              const Gap(DDSSpacing.sm),

              // Transaction List
              transactionsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading transactions: $err', style: DDSTypography.bodyMedium.copyWith(color: DDSColors.errorRed)),
                ),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(DDSSpacing.xl),
                      decoration: BoxDecoration(
                        color: DDSColors.surfaceCard,
                        borderRadius: DDSRadius.largeBorderRadius,
                        border: Border.all(color: DDSColors.borderLight),
                        boxShadow: DDSElevation.cardShadow,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: DDSColors.textMuted),
                            const Gap(12),
                            Text(
                              'No transactions yet',
                              style: DDSTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: DDSColors.textPrimary),
                            ),
                            const Gap(4),
                            Text(
                              'Your deposits, booking payments, and rewards will appear here.',
                              textAlign: TextAlign.center,
                              style: DDSTypography.bodyMedium.copyWith(fontSize: 12, color: DDSColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (ctx, idx) {
                      final tx = transactions[idx];
                      final isCredit = tx.direction == LedgerDirection.CREDIT;

                      return Container(
                        decoration: BoxDecoration(
                          color: DDSColors.surfaceCard,
                          borderRadius: DDSRadius.mediumBorderRadius,
                          border: Border.all(color: DDSColors.borderLight),
                          boxShadow: DDSElevation.cardShadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCredit
                                  ? DDSColors.successGreenBg
                                  : DDSColors.errorRedBg,
                              child: Icon(
                                isCredit
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isCredit ? DDSColors.successGreen : DDSColors.errorRed,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              tx.description,
                              style: DDSTypography.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: DDSColors.textPrimary),
                            ),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt),
                              style: DDSTypography.bodyMedium.copyWith(fontSize: 11, color: DDSColors.textMuted),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                                  style: DDSTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isCredit ? DDSColors.successGreen : DDSColors.errorRed,
                                  ),
                                ),
                                Text(
                                  'Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                                  style: DDSTypography.labelSmall.copyWith(fontSize: 10, color: DDSColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceChip({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const Gap(6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.labelSmall.copyWith(fontSize: 11, color: DDSColors.textMuted),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DDSTypography.titleMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
