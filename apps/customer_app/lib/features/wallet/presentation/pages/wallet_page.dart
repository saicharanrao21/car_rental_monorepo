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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deposit verification failed: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.orange,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Money to Wallet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(12),
                const Text(
                  'Enter amount (Min ₹100 - Max ₹50,000)',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Gap(12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
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
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _presetChip(amountController, 500),
                    _presetChip(amountController, 1000),
                    _presetChip(amountController, 2000),
                    _presetChip(amountController, 5000),
                  ],
                ),
                const Gap(24),
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
                          backgroundColor: Colors.red,
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
      label: Text('+₹$amount'),
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
        title: const Text('DriveGo Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Card
              walletAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load wallet: $err'),
                  ),
                ),
                data: (wallet) {
                  return AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: wallet.status == WalletStatus.ACTIVE
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  wallet.status.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: wallet.status == WalletStatus.ACTIVE
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            '₹${wallet.availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Gap(16),
                          const Divider(),
                          const Gap(8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _balanceChip(
                                label: 'Real Cash',
                                amount: wallet.realBalance,
                                icon: Icons.account_balance_wallet_outlined,
                                color: Colors.blue.shade700,
                              ),
                              _balanceChip(
                                label: 'Promo / Rewards',
                                amount: wallet.promoBalance,
                                icon: Icons.stars_outlined,
                                color: Colors.purple.shade700,
                              ),
                            ],
                          ),
                          const Gap(20),
                          AppButton(
                            text: '+ Add Money',
                            onPressed: () => _showAddMoneyBottomSheet(context),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Gap(24),
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Gap(12),

              // Transaction List
              transactionsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading transactions: $err'),
                ),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const AppCard(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 48, color: Colors.grey),
                              Gap(12),
                              Text(
                                'No transactions yet',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Gap(4),
                              Text(
                                'Your deposits, booking payments, and rewards will appear here.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
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

                      return AppCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCredit
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            child: Icon(
                              isCredit
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isCredit ? Colors.green : Colors.red,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            tx.description,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(tx.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                'Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
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
      children: [
        Icon(icon, size: 16, color: color),
        const Gap(6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
