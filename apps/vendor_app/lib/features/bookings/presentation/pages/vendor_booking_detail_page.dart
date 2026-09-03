import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';
import '../widgets/inspection_history_card.dart';
import '../widgets/damage_claim_submission_sheet.dart';

class VendorBookingDetailPage extends ConsumerStatefulWidget {
  final String bookingId;

  const VendorBookingDetailPage({super.key, required this.bookingId});

  @override
  ConsumerState<VendorBookingDetailPage> createState() => _VendorBookingDetailPageState();
}

class _VendorBookingDetailPageState extends ConsumerState<VendorBookingDetailPage> {
  bool _isLoadingAction = false;
  bool _isSendingOtp = false;
  final _otpCtrl = TextEditingController();
  DateTime? _lastOtpSentAt;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _openDamageClaimSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DamageClaimSubmissionSheet(
        bookingId: widget.bookingId,
        onSubmitted: () {
          ref.invalidate(bookingDamageClaimsProvider(widget.bookingId));
        },
      ),
    );
  }

  Future<void> _sendOtp(String otpType) async {
    // 60s cooldown check
    if (_lastOtpSentAt != null &&
        DateTime.now().difference(_lastOtpSentAt!).inSeconds < 60) {
      final remaining = 60 - DateTime.now().difference(_lastOtpSentAt!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait $remaining seconds before requesting another OTP')),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    final success = await ref
        .read(vendorBookingsProvider.notifier)
        .sendHandoverOtp(widget.bookingId, otpType);

    if (mounted) {
      setState(() {
        _isSendingOtp = false;
        if (success) {
          _lastOtpSentAt = DateTime.now();
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Text(
              '${otpType == 'PICKUP' ? 'Pickup' : 'Return'} OTP successfully sent to customer\'s registered mobile number.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to dispatch handover OTP. Please try again.')),
        );
      }
    }
  }

  Future<void> _verifyAndTransition({
    required String targetStatus,
    required String successMessage,
  }) async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit customer handover OTP')),
      );
      return;
    }

    setState(() {
      _isLoadingAction = true;
    });

    final success = await ref.read(vendorBookingsProvider.notifier).updateStatus(
      widget.bookingId,
      targetStatus,
      handoverOtp: otp,
    );

    if (mounted) {
      setState(() {
        _isLoadingAction = false;
      });

      if (success) {
        _otpCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Text(successMessage),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handover verification failed. Please ensure the inspection is finalized and OTP is correct.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsVal = ref.watch(vendorBookingsProvider);
    final bookingFromList = bookingsVal.maybeWhen(
      data: (list) {
        final idx = list.indexWhere((b) => b.id == widget.bookingId);
        return idx != -1 ? list[idx] : null;
      },
      orElse: () => null,
    );
    final bookingSingle = ref.watch(singleBookingProvider(widget.bookingId)).valueOrNull;
    final booking = bookingFromList ?? bookingSingle;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: bookingsVal.isLoading
            ? const Center(child: AppLoader())
            : const Center(child: Text('Booking not found')),
      );
    }

    final inspectionsVal = ref.watch(bookingInspectionsProvider(booking.id));
    final inspections = inspectionsVal.value ?? [];
    final preTrip = inspections.where((i) => i.type == 'PRE_TRIP').firstOrNull;
    final postTrip = inspections.where((i) => i.type == 'POST_TRIP').firstOrNull;

    final customerName = 'Customer #${booking.customerId.length > 6 ? booking.customerId.substring(0, 6) : booking.customerId}';
    final carTitle = 'Vehicle #${booking.carId.length > 6 ? booking.carId.substring(0, 6) : booking.carId}';

    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final startStr = formatter.format(booking.startDate);
    final endStr = formatter.format(booking.endDate);

    final statusLower = booking.status.toLowerCase();
    final emergencyAsync = ref.watch(vendorBookingEmergencyProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking ${booking.id}'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Roadside Incident Alert Banner if reported
                emergencyAsync.when(
                  data: (emergency) {
                    if (emergency == null) return const SizedBox.shrink();
                    final isResolved = emergency.status == EmergencyStatus.RESOLVED;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isResolved
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isResolved ? Colors.green : Colors.red),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isResolved ? Icons.check_circle : Icons.emergency,
                                color: isResolved ? Colors.green : Colors.red,
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  'ROADSIDE ASSISTANCE: ${emergency.incidentType.label}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isResolved
                                        ? Colors.green.shade800
                                        : Colors.red.shade900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isResolved ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  emergency.status.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (emergency.customerNotes != null) ...[
                            const Gap(6),
                            Text('Customer Notes: ${emergency.customerNotes}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                          if (emergency.locationAddress != null) ...[
                            const Gap(4),
                            Text('Location: ${emergency.locationAddress}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // Status Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    StatusBadge(status: booking.status),
                  ],
                ),
                // Active Handover Workflow Card (Pending / Pickup / Return)
                if (statusLower == 'pending')
                  _buildPendingDecisionCard(booking.id)
                else if (statusLower == 'confirmed')
                  _buildPickupWorkflowCard(preTrip)
                else if (statusLower == 'ongoing')
                  _buildReturnWorkflowCard(preTrip, postTrip),

                // Vehicle Details Card
                const Text('Vehicle Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                carTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Gap(4),
                              Text(
                                'Trip: ${booking.tripType}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Trip Duration & Route Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Trip Schedule & Fulfillment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Gap(8),
                    _buildFulfillmentBadge(booking),
                  ],
                ),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.calendar_today, 'Start Date & Time', startStr),
                        const Divider(height: 20),
                        _buildInfoRow(Icons.event, 'End Date & Time', endStr),
                        const Divider(height: 20),
                        _buildPickupLocationCard(context, booking),
                        if (booking.dropLocation != null || booking.dropName != null) ...[
                          const Gap(12),
                          _buildDropoffLocationCard(context, booking),
                        ],
                        _buildFulfillmentPayoutCard(booking),
                        const Divider(height: 20),
                        _buildInfoRow(Icons.work_outline, 'Trip Type', booking.tripType),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Customer Details Card
                const Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: AppColors.primary),
                            ),
                            const Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const Gap(4),
                                  Text(
                                    '+91 XXXXX XXXXX',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[800], size: 16),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  'Contact via platform only. Real contact numbers are hidden for privacy.',
                                  style: TextStyle(color: Colors.amber[900], fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),

                // Inspection History for Completed Bookings
                if (inspections.isNotEmpty) ...[
                  const Text('Inspection Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Gap(12),
                  ...inspections.map((insp) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InspectionHistoryCard(inspection: insp),
                      )),
                  const Gap(12),
                ],

                // Post-Trip Damage Claims
                if (booking.status.toLowerCase() == 'completed') ...[
                  _buildDamageClaimSection(),
                  const Gap(24),
                ],

                // Payout Transparency Breakdown
                const Text('Earnings Transparency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFareRow('Total Customer Fare', booking.totalFare, isBold: true),
                        const Gap(10),
                        if ((booking.deliveryFee ?? 0) > 0) ...[
                          _buildFareRow('Doorstep Delivery (Earned)', booking.deliveryFee ?? 0, color: const Color(0xFF3730A3)),
                          const Gap(6),
                        ],
                        if ((booking.oneWayFee ?? 0) > 0) ...[
                          _buildFareRow('One-Way Relocation (Earned)', booking.oneWayFee ?? 0, color: const Color(0xFF92400E)),
                          const Gap(6),
                        ],
                        if ((booking.pickupFee ?? 0) > 0) ...[
                          _buildFareRow('Pickup Hub Fee (Earned)', booking.pickupFee ?? 0, color: const Color(0xFF0066FF)),
                          const Gap(6),
                        ],
                        if ((booking.returnFee ?? 0) > 0) ...[
                          _buildFareRow('Return Hub Fee (Earned)', booking.returnFee ?? 0, color: const Color(0xFF059669)),
                          const Gap(6),
                        ],
                        _buildFareRow('Platform Fee (Subtracted)', -booking.platformFee, color: Colors.red[700]),
                        const Gap(6),
                        _buildFareRow('GST/Taxes (Subtracted)', -booking.gstAmount, color: Colors.red[700]),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Payout (Net)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            PriceTag(
                              amount: booking.netToVendor,
                              amountStyle: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(40),
              ],
            ),
          ),
          if (_isLoadingAction)
            Container(
              color: Colors.black26,
              child: const Center(
                child: AppLoader(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickupWorkflowCard(InspectionModel? preTrip) {
    final hasFinalizedPreTrip = preTrip != null && preTrip.finalized;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vehicle Handover & Pickup Flow',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(12),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1: Pre-Trip Inspection
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hasFinalizedPreTrip ? Colors.green : Colors.blue,
                      child: Text(
                        hasFinalizedPreTrip ? '✓' : '1',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Gap(10),
                    const Text(
                      'Step 1: Pre-Trip Inspection',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Gap(8),
                if (!hasFinalizedPreTrip) ...[
                  Text(
                    'Record vehicle odometer, fuel level, and condition before handing over keys.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Gap(10),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/bookings/${widget.bookingId}/handover'),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Start 60s Handover Inspection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Pre-Trip Finalized: ${preTrip.odometer.toStringAsFixed(1)} km | Fuel: ${preTrip.fuelPercent}%',
                            style: TextStyle(color: Colors.green[900], fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),

                // Step 2: Handover OTP
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hasFinalizedPreTrip ? Colors.blue : Colors.grey,
                      child: const Text(
                        '2',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Gap(10),
                    const Text(
                      'Step 2: Customer Handover OTP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request OTP from customer and enter below to confirm physical handover.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    const Gap(8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 36)),
                      onPressed: _isSendingOtp ? null : () => _sendOtp('PICKUP'),
                      icon: _isSendingOtp
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_isSendingOtp ? 'Sending...' : 'Send Pickup OTP'),
                    ),
                  ],
                ),
                const Gap(12),
                AppTextField(
                  label: '6-Digit Customer Pickup OTP',
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  hint: 'Enter OTP provided by customer',
                ),
                const Gap(16),

                // Start Trip Button
                AppButton(
                  text: 'Verify OTP & Start Trip',
                  onPressed: !hasFinalizedPreTrip
                      ? null
                      : () => _verifyAndTransition(
                            targetStatus: 'ongoing',
                            successMessage: 'Pickup verified and trip started successfully!',
                          ),
                ),
                if (!hasFinalizedPreTrip) ...[
                  const Gap(6),
                  Text(
                    'Complete Step 1 (Pre-Trip Inspection) to enable trip start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Gap(24),
      ],
    );
  }

  Widget _buildReturnWorkflowCard(InspectionModel? preTrip, InspectionModel? postTrip) {
    final hasFinalizedPostTrip = postTrip != null && postTrip.finalized;
    final minOdometer = preTrip?.odometer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vehicle Return & Handover Flow',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(12),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1: Post-Trip Inspection
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hasFinalizedPostTrip ? Colors.green : Colors.purple,
                      child: Text(
                        hasFinalizedPostTrip ? '✓' : '1',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Gap(10),
                    const Text(
                      'Step 1: Post-Trip Inspection',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Gap(8),
                if (!hasFinalizedPostTrip) ...[
                  Text(
                    'Record return odometer (>= ${minOdometer ?? 0} km), fuel level, and any new damage.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Gap(10),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/bookings/${widget.bookingId}/return'),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Start 60s Return Inspection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Post-Trip Finalized: ${postTrip.odometer.toStringAsFixed(1)} km | Fuel: ${postTrip.fuelPercent}%',
                            style: TextStyle(color: Colors.green[900], fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),

                // Step 2: Return Handover OTP
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hasFinalizedPostTrip ? Colors.purple : Colors.grey,
                      child: const Text(
                        '2',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Gap(10),
                    const Text(
                      'Step 2: Customer Return OTP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Customer receives a return 6-digit OTP to authorize trip completion.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Gap(10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 36)),
                      onPressed: _isSendingOtp ? null : () => _sendOtp('RETURN'),
                      icon: _isSendingOtp
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_isSendingOtp ? 'Sending...' : 'Send Return OTP'),
                    ),
                  ],
                ),
                const Gap(12),
                AppTextField(
                  label: '6-Digit Customer Return OTP',
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  hint: 'Enter OTP provided by customer',
                ),
                const Gap(16),

                // Complete Trip Button
                AppButton(
                  text: 'Verify OTP & Complete Trip',
                  onPressed: !hasFinalizedPostTrip
                      ? null
                      : () => _verifyAndTransition(
                            targetStatus: 'completed',
                            successMessage: 'Return verified and trip completed successfully!',
                          ),
                ),
                if (!hasFinalizedPostTrip) ...[
                  const Gap(6),
                  Text(
                    'Complete Step 1 (Post-Trip Inspection) to enable trip completion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Gap(24),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const Gap(2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.grey[800],
          ),
        ),
        PriceTag(
          amount: amount.abs(),
          amountStyle: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (amount < 0 ? Colors.red[700] : Colors.black87),
          ),
          suffix: amount < 0 ? ' -' : null,
        ),
      ],
    );
  }

  Widget _buildDamageClaimSection() {
    final claimsAsync = ref.watch(bookingDamageClaimsProvider(widget.bookingId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vehicle Damage Claims',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => ref.invalidate(bookingDamageClaimsProvider(widget.bookingId)),
            ),
          ],
        ),
        const Gap(8),
        claimsAsync.when(
          data: (claims) {
            if (claims.isEmpty) {
              return AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                          const Gap(10),
                          const Text(
                            'No Damage Reported',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        'If new damage was discovered during post-trip return inspection, submit a claim with repair estimates and photo evidence for admin adjudication.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Gap(14),
                      OutlinedButton.icon(
                        onPressed: _openDamageClaimSheet,
                        icon: const Icon(Icons.report_problem_outlined, size: 16, color: Colors.red),
                        label: const Text('Report Vehicle Damage', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final claim = claims.first;
            final (statusText, statusBg, statusFg) = _resolveClaimStatusStyle(claim.status);

            return AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 18, color: Colors.red),
                            const Gap(8),
                            const Text(
                              'Claim #',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              claim.id.length > 8 ? claim.id.substring(0, 8) : claim.id,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Claimed Repair Cost:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        PriceTag(
                          amount: claim.claimedAmount,
                          amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                    if (claim.approvedAmount != null) ...[
                      const Gap(4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Approved Deducted Amount:', style: TextStyle(fontSize: 13, color: Colors.green)),
                          PriceTag(
                            amount: claim.approvedAmount!,
                            amountStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                    const Gap(10),
                    Text(
                      'Description: ${claim.description}',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    if (claim.damagePhotos.isNotEmpty) ...[
                      const Gap(10),
                      Text(
                        'Attached Photos: ${claim.damagePhotos.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (claim.adminNotes != null && claim.adminNotes!.isNotEmpty) ...[
                      const Gap(10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.gavel, size: 16, color: Colors.blue),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                'Admin Resolution: ${claim.adminNotes}',
                                style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  (String, Color, Color) _resolveClaimStatusStyle(DamageClaimStatus status) {
    switch (status) {
      case DamageClaimStatus.SUBMITTED:
        return ('SUBMITTED', Colors.amber.withValues(alpha: 0.15), Colors.amber[900]!);
      case DamageClaimStatus.UNDER_REVIEW:
        return ('UNDER REVIEW', Colors.blue.withValues(alpha: 0.15), Colors.blue[900]!);
      case DamageClaimStatus.APPROVED:
        return ('APPROVED', Colors.green.withValues(alpha: 0.15), Colors.green[900]!);
      case DamageClaimStatus.PARTIALLY_APPROVED:
        return ('PARTIALLY APPROVED', Colors.orange.withValues(alpha: 0.15), Colors.orange[900]!);
      case DamageClaimStatus.REJECTED:
        return ('REJECTED', Colors.red.withValues(alpha: 0.15), Colors.red[900]!);
      case DamageClaimStatus.SETTLED:
        return ('SETTLED', Colors.purple.withValues(alpha: 0.15), Colors.purple[900]!);
    }
  }

  void _showRejectBottomSheet(String bookingId) {
    String selectedReason = 'Vehicle undergoing maintenance';
    final reasons = [
      'Vehicle undergoing maintenance',
      'Vehicle not returned on time by previous renter',
      'Pricing error or incorrect rates',
      'Driver unavailable',
      'Other',
    ];

    AppBottomSheet.show(
      context,
      title: 'Reject Booking Request',
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please select a reason for rejecting this booking request. A 100% refund will be automatically processed for the customer.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Gap(16),
              AppDropdown<String>(
                label: 'Reason',
                value: selectedReason,
                items: reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(r),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() {
                      selectedReason = val;
                    });
                  }
                },
              ),
              const Gap(24),
              AppButton(
                text: 'Reject Booking',
                backgroundColor: Colors.red[700],
                onPressed: () async {
                  Navigator.pop(sheetCtx); // Close bottom sheet
                  setState(() => _isLoadingAction = true);
                  final success = await ref
                      .read(vendorBookingsProvider.notifier)
                      .reject(bookingId, selectedReason);
                  if (mounted) {
                    setState(() => _isLoadingAction = false);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Booking request rejected. Full refund initiated.')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingDecisionCard(String bookingId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Booking Request Decision',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Gap(12),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pending_actions, color: Colors.amber, size: 22),
                    ),
                    const Gap(12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paid Booking Awaiting Your Approval',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Gap(2),
                          Text(
                            'Review the vehicle and trip details below before accepting or rejecting.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRejectBottomSheet(bookingId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reject Request'),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: AppButton(
                        text: 'Accept Booking',
                        onPressed: () async {
                          setState(() => _isLoadingAction = true);
                          final success = await ref
                              .read(vendorBookingsProvider.notifier)
                              .updateStatus(bookingId, 'confirmed');
                          if (mounted) {
                            setState(() => _isLoadingAction = false);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Booking request accepted successfully!')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(24),
      ],
    );
  }

  Widget _buildFulfillmentPayoutCard(BookingModel booking) {
    final deliveryFee = booking.deliveryFee ?? 0.0;
    final pickupFee = booking.pickupFee ?? 0.0;
    final returnFee = booking.returnFee ?? 0.0;
    final oneWayFee = booking.oneWayFee ?? 0.0;

    final hasFulfillmentFees = deliveryFee > 0 || pickupFee > 0 || returnFee > 0 || oneWayFee > 0;
    if (!hasFulfillmentFees) {
      return const SizedBox.shrink();
    }

    final totalFulfillmentRevenue = deliveryFee + pickupFee + returnFee + oneWayFee;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFF166534)),
                  Gap(6),
                  Text(
                    'FULFILLMENT REVENUE BREAKDOWN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  '+₹${totalFulfillmentRevenue.toInt()} Earned',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          if (deliveryFee > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('+₹${deliveryFee.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ],
              ),
            ),
          if (pickupFee > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Collection Fee / Pickup Fee', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('+₹${pickupFee.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ],
              ),
            ),
          if (oneWayFee > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('One-Way Relocation Fee', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('+₹${oneWayFee.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ],
              ),
            ),
          if (returnFee > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hub Fee / Return Fee', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  Text('+₹${returnFee.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentBadge(BookingModel booking) {
    final isDoorstep = booking.deliveryType == 'DOORSTEP_DELIVERY' || booking.deliveryAddress != null;
    final isTransit = booking.deliveryType == 'PUBLIC_LOCATION' ||
        (booking.pickupHubId != null && booking.pickupHubId!.startsWith('pub_'));
    final isDiffReturn = (booking.oneWayFee ?? 0) > 0 || (booking.dropName != null && booking.dropName != booking.pickupName);

    String label = 'HOST YARD';
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF166534);
    IconData icon = Icons.garage_outlined;

    if (isDoorstep) {
      label = 'DOORSTEP DELIVERY';
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
      icon = Icons.local_shipping_outlined;
    } else if (isTransit) {
      label = 'TRANSIT HUB / PUBLIC LOCATION';
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF6B21A8);
      icon = Icons.connecting_airports_outlined;
    } else if (isDiffReturn) {
      label = 'DIFFERENT RETURN BRANCH';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      icon = Icons.alt_route_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const Gap(4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupLocationCard(BuildContext context, BookingModel booking) {
    final isDoorstep = booking.deliveryType == 'DOORSTEP_DELIVERY' || booking.deliveryAddress != null;
    final header = isDoorstep ? 'DOORSTEP DELIVERY DESTINATION' : 'PICKUP / HANDOVER LOCATION';
    final name = booking.pickupName ?? (isDoorstep ? 'Customer Delivery Address' : booking.pickupLocation);
    final address = isDoorstep
        ? (booking.deliveryAddress ?? booking.pickupAddress)
        : (booking.pickupAddress ?? booking.pickupLocation);
    final subtitle = isDoorstep ? 'Deliver & handover car at customer doorstep' : 'Customer picks up car at branch/hub';
    final feeBadge = (booking.deliveryFee ?? 0) > 0
        ? '+₹${booking.deliveryFee!.toInt()} Delivery'
        : ((booking.pickupFee ?? 0) > 0 ? '+₹${booking.pickupFee!.toInt()} Hub Fee' : 'Free');

    return _buildLocationActionCard(
      context,
      header,
      name,
      subtitle,
      const Color(0xFF0066FF),
      isDoorstep ? Icons.local_shipping_outlined : Icons.trip_origin,
      address: address,
      latitude: booking.deliveryLatitude ?? booking.pickupLatitude,
      longitude: booking.deliveryLongitude ?? booking.pickupLongitude,
      feeBadge: feeBadge,
    );
  }

  Widget _buildDropoffLocationCard(BuildContext context, BookingModel booking) {
    final isOneWay = (booking.oneWayFee ?? 0) > 0;
    final dropName = booking.dropName ?? booking.dropLocation ?? 'Same Location';
    final header = isOneWay ? 'DIFFERENT RETURN BRANCH' : 'RETURN / DROP-OFF LOCATION';
    final address = booking.deliveryAddress ?? booking.dropLocation;
    final subtitle = isOneWay ? 'Vehicle will be returned at alternate branch' : 'Scheduled vehicle return';
    final feeBadge = isOneWay
        ? '+₹${booking.oneWayFee!.toInt()} Relocation'
        : ((booking.returnFee ?? 0) > 0 ? '+₹${booking.returnFee!.toInt()} Return Fee' : null);

    return _buildLocationActionCard(
      context,
      header,
      dropName,
      subtitle,
      const Color(0xFF059669),
      isOneWay ? Icons.alt_route_outlined : Icons.location_on,
      address: address,
      feeBadge: feeBadge,
    );
  }

  Widget _buildLocationActionCard(
    BuildContext context,
    String header,
    String locationName,
    String subtitle,
    Color accentColor,
    IconData icon, {
    String? address,
    double? latitude,
    double? longitude,
    String? feeBadge,
  }) {
    final hasCoordinates = latitude != null && longitude != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  const Gap(6),
                  Text(
                    header,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (feeBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    feeBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(6),
          Text(
            locationName,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
          ),
          if (address != null && address.isNotEmpty && address != locationName) ...[
            const Gap(2),
            Text(
              address,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ],
          const Gap(2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const Gap(10),
          InkWell(
            onTap: () {
              final navTarget = hasCoordinates
                  ? '(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})'
                  : locationName;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening GPS navigation to $navTarget')),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions, size: 14, color: accentColor),
                  const Gap(4),
                  Text(
                    hasCoordinates
                        ? 'GPS: ${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}'
                        : 'NAVIGATE / DIRECTIONS',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

