import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../providers/vendor_bookings_providers.dart';
import '../widgets/handover_inspection_sheet.dart';
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

  void _openInspectionSheet(String type, double? minOdo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HandoverInspectionSheet(
        bookingId: widget.bookingId,
        type: type,
        minOdometer: minOdo,
        onSaved: () {
          ref.invalidate(bookingInspectionsProvider(widget.bookingId));
        },
      ),
    );
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
    final booking = bookingsVal.maybeWhen(
      data: (list) {
        final idx = list.indexWhere((b) => b.id == widget.bookingId);
        return idx != -1 ? list[idx] : null;
      },
      orElse: () => null,
    );

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
                const Divider(height: 32),

                // Active Handover Workflow Card (Pickup / Return)
                if (statusLower == 'confirmed')
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
                const Text('Trip Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.calendar_today, 'Start Date & Time', startStr),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.event, 'End Date & Time', endStr),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.my_location, 'Pickup Location', booking.pickupLocation),
                        if (booking.dropLocation != null) ...[
                          const Divider(height: 24),
                          _buildInfoRow(Icons.location_on, 'Drop Location', booking.dropLocation!),
                        ],
                        const Divider(height: 24),
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
                    onPressed: () => _openInspectionSheet('PRE_TRIP', null),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Record Pre-Trip Inspection'),
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
                Text(
                  'Customer receives a 6-digit OTP via SMS when you initiate handover.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Gap(10),
                Row(
                  children: [
                    OutlinedButton.icon(
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
                    onPressed: () => _openInspectionSheet('POST_TRIP', minOdometer),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Record Post-Trip Inspection'),
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
}
