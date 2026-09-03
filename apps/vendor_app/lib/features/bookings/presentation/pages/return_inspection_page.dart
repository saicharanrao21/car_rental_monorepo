import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/vendor_bookings_providers.dart';

class ReturnInspectionPage extends ConsumerStatefulWidget {
  final String bookingId;
  final int initialStep;
  final bool? hasNewDamage;
  final bool showSuccessDialog;
  final bool showValidationError;

  const ReturnInspectionPage({
    super.key,
    required this.bookingId,
    this.initialStep = 0,
    this.hasNewDamage,
    this.showSuccessDialog = false,
    this.showValidationError = false,
  });

  @override
  ConsumerState<ReturnInspectionPage> createState() => _ReturnInspectionPageState();
}

class _ReturnInspectionPageState extends ConsumerState<ReturnInspectionPage> {
  int _currentStep = 0; // 0: Odo & Fuel Delta, 1: 4-Photo Return Burst, 2: Before/After Damage, 3: Review & Complete
  final _formKey = GlobalKey<FormState>();

  // Baseline pre-trip values
  final double _handoverOdometer = 42390.0;
  final int _handoverFuelPercent = 100;

  // Return values
  late final TextEditingController _returnOdometerCtrl;
  int _returnFuelPercent = 75; // 0, 25, 50, 75, 100

  // 4-Photo Return Burst
  final Map<String, String> _returnBurstPhotos = {
    'Front': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341',
    'Rear': 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
    'Left Side': 'https://images.unsplash.com/photo-1503376780353-7e6692767b70',
    'Right Side': 'https://images.unsplash.com/photo-1583121274602-3e2820c69888',
  };

  // Damage Comparison
  bool _newDamageDetected = true;
  final String _newDamageLocation = 'Right Rear Fender';
  final String _newDamageSeverity = 'Minor';
  final _newDamageNotesCtrl = TextEditingController(text: 'Surface scratch on lower edge, ~3cm');
  final _claimAmountCtrl = TextEditingController(text: '1500');

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _returnOdometerCtrl = TextEditingController(text: widget.showValidationError ? '41000' : '42681');
    if (widget.hasNewDamage != null) {
      _newDamageDetected = widget.hasNewDamage!;
    }
    if (widget.showValidationError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }
    if (widget.showSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessDialogDirect();
      });
    }
  }

  @override
  void dispose() {
    _returnOdometerCtrl.dispose();
    _newDamageNotesCtrl.dispose();
    _claimAmountCtrl.dispose();
    super.dispose();
  }

  Color _getFuelColor(int percent) {
    if (percent <= 25) return const Color(0xFFEF4444);
    if (percent <= 50) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  double get _distanceDriven {
    final retOdo = double.tryParse(_returnOdometerCtrl.text.trim()) ?? _handoverOdometer;
    return retOdo > _handoverOdometer ? retOdo - _handoverOdometer : 0.0;
  }

  int get _fuelDifference {
    return _handoverFuelPercent - _returnFuelPercent;
  }

  String? _validateReturnOdometer(String? val) {
    if (val == null || val.trim().isEmpty) return 'Enter return odometer reading';
    final num = double.tryParse(val.trim());
    if (num == null || num <= 0) return 'Enter valid positive number';
    if (num < _handoverOdometer) {
      return 'Return reading (${num.toInt()} km) cannot be less than handover reading (${_handoverOdometer.toInt()} km)';
    }
    return null;
  }

  Future<void> _submitReturn() async {
    setState(() => _isSubmitting = true);

    final retOdo = double.tryParse(_returnOdometerCtrl.text.trim()) ?? 42681.0;
    final damageNotes = _newDamageDetected
        ? 'NEW DAMAGE DETECTED: $_newDamageLocation ($_newDamageSeverity) - ${_newDamageNotesCtrl.text.trim()}'
        : 'No new damages. Vehicle returned in good condition.';

    final success = await ref.read(vendorBookingsProvider.notifier).completeReturn(
      bookingId: widget.bookingId,
      odometer: retOdo,
      fuelPercent: _returnFuelPercent,
      conditionNotes: damageNotes,
      damagePhotos: _returnBurstPhotos.values.toList(),
    );

    if (_newDamageDetected && success) {
      final claimAmt = double.tryParse(_claimAmountCtrl.text.trim()) ?? 1500.0;
      await ref.read(vendorBookingsProvider.notifier).submitDamageClaim(
        widget.bookingId,
        claimedAmount: claimAmt,
        description: damageNotes,
        damagePhotos: [_returnBurstPhotos['Right Side'] ?? ''],
        vendorNotes: 'Recorded during rapid return inspection.',
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              Gap(10),
              Text('Return Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle return inspection finalized. Trip closed and booking marked COMPLETED.',
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Total Distance', '${_distanceDriven.toInt()} km'),
                    const Gap(6),
                    _buildSummaryRow('Fuel Shortfall', _fuelDifference > 0 ? '$_fuelDifference%' : 'None (Full)'),
                    const Gap(6),
                    _buildSummaryRow('New Damages', _newDamageDetected ? '1 Claim Filed' : 'None'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/bookings');
              },
              child: const Text('Back to Operations'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Failed to complete return inspection. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(singleBookingProvider(widget.bookingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Return Inspection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Builder(
        builder: (context) {
          final fallbackBooking = bookingAsync.valueOrNull ??
              BookingModel(
                id: widget.bookingId,
                customerId: 'cust_849201',
                vendorId: 'vendor_01',
                carId: 'car_hyundai_creta',
                tripType: 'Outstation',
                pickupLocation: 'Terminal 2, Mumbai Airport',
                startDate: DateTime.now().subtract(const Duration(days: 3)),
                endDate: DateTime.now(),
                totalFare: 9600.0,
                platformFee: 960.0,
                gstAmount: 1728.0,
                netToVendor: 8640.0,
                status: 'ongoing',
                createdAt: DateTime.now().subtract(const Duration(days: 3)),
              );

          return Column(
            children: [
              _buildProgressHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_currentStep == 0) _buildStep0OdometerFuel(fallbackBooking),
                      if (_currentStep == 1) _buildStep1PhotoBurst(),
                      if (_currentStep == 2) _buildStep2BeforeAfterDamage(),
                      if (_currentStep == 3) _buildStep3Review(fallbackBooking),
                      const Gap(24),
                    ],
                  ),
                ),
              ),
              _buildBottomActionNav(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader() {
    final stepTitles = ['Odo & Fuel Delta', '4-Photos Return', 'Damage Comparison', 'Review & Complete'];
    final progress = (_currentStep + 1) / stepTitles.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'STEP ${_currentStep + 1} OF ${stepTitles.length}: ${stepTitles[_currentStep].toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0066FF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '⚡ 60s Fast Flow',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0066FF)),
                ),
              ),
            ],
          ),
          const Gap(8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnLocationBanner(BookingModel booking) {
    final isOneWay = (booking.oneWayFee ?? 0) > 0 || (booking.dropName != null && booking.dropName != booking.pickupName);
    final isDoorstepReturn = booking.deliveryType == 'DOORSTEP_DELIVERY' && booking.deliveryAddress != null;

    final locationTitle = booking.dropName ??
        (isDoorstepReturn ? 'Customer Doorstep Collection' : (booking.dropLocation ?? booking.pickupLocation));
    final locationAddress = booking.deliveryAddress ?? booking.dropLocation ?? booking.pickupLocation;

    final bannerBg = isOneWay
        ? const Color(0xFFFFFBEB)
        : (isDoorstepReturn ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4));
    final bannerBorder = isOneWay
        ? const Color(0xFFFDE68A)
        : (isDoorstepReturn ? const Color(0xFFC7D2FE) : const Color(0xFFBBF7D0));
    final titleColor = isOneWay
        ? const Color(0xFF92400E)
        : (isDoorstepReturn ? const Color(0xFF3730A3) : const Color(0xFF166534));
    final badgeLabel = isOneWay
        ? 'RELOCATION BRANCH'
        : (isDoorstepReturn ? 'DOORSTEP COLLECTION' : 'RETURN YARD');
    final iconData = isOneWay
        ? Icons.alt_route_outlined
        : (isDoorstepReturn ? Icons.local_shipping_outlined : Icons.location_on_outlined);

    final contextNote = isOneWay
        ? 'Vehicle scheduled for return at alternate branch (Relocation).'
        : (isDoorstepReturn
            ? 'Vehicle scheduled for doorstep collection from customer.'
            : 'Vehicle return scheduled at vendor\'s primary operating yard.');

    final lat = booking.deliveryLatitude ?? booking.pickupLatitude;
    final lng = booking.deliveryLongitude ?? booking.pickupLongitude;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 20, color: titleColor),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'RETURN DESTINATION',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: bannerBorder),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  locationTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                if (locationAddress != locationTitle) ...[
                  const Gap(2),
                  Text(
                    locationAddress,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
                const Gap(2),
                Text(
                  contextNote,
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: titleColor.withValues(alpha: 0.8)),
                ),
                if (lat != null && lng != null) ...[
                  const Gap(8),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening GPS navigation to (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})')),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: bannerBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions, size: 14, color: titleColor),
                          const Gap(4),
                          Text(
                            'NAVIGATE GPS (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: titleColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0OdometerFuel(BookingModel booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReturnLocationBanner(booking),
        const Gap(14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Odometer Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Handover: ${_handoverOdometer.toInt()} km',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                TextFormField(
                  controller: _returnOdometerCtrl,
                  keyboardType: TextInputType.number,
                  validator: _validateReturnOdometer,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                  decoration: InputDecoration(
                    labelText: 'Current Return Reading',
                    suffixText: 'KM',
                    suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route_rounded, color: Color(0xFF16A34A), size: 20),
                      const Gap(8),
                      Text(
                        'Distance Travelled: ${_distanceDriven.toInt()} km',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Return Fuel Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const Gap(8),
                    Flexible(
                      child: Text(
                        '$_returnFuelPercent% (Handover: $_handoverFuelPercent%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getFuelColor(_returnFuelPercent),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _returnFuelPercent / 100.0,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(_getFuelColor(_returnFuelPercent)),
                  ),
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0, 25, 50, 75, 100].map((val) {
                    final isSelected = _returnFuelPercent == val;
                    final label = val == 0 ? 'E' : val == 100 ? 'F' : '$val%';

                    return InkWell(
                      onTap: () => setState(() => _returnFuelPercent = val),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_fuelDifference > 0) ...[
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_gas_station_rounded, color: Color(0xFFD97706), size: 18),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            'Fuel Shortfall: -$_fuelDifference% (Refuel charge will apply)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1PhotoBurst() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4-Angle Return Exterior Burst',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Text(
          'Capture current condition of all 4 sides upon vehicle return.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: _returnBurstPhotos.entries.map((entry) {
            return _buildBurstPhotoCard(entry.key, entry.value);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBurstPhotoCard(String angleName, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8), size: 40),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 12),
                        Gap(2),
                        Text('Captured', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  angleName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B192C)),
                ),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Retake return $angleName photo')),
                    );
                  },
                  child: const Text('Retake', style: TextStyle(fontSize: 12, color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2BeforeAfterDamage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Before & After Damage Comparison',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Text(
          'Compare Handover (Pre-Trip) inspection photos with Return photos to detect new damage.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text('Side-by-Side Visual Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Gap(8),
                    Flexible(
                      child: Text('Right Side Angle', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                'https://images.unsplash.com/photo-1583121274602-3e2820c69888',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE2E8F0),
                                  child: const Center(child: Icon(Icons.directions_car, color: Color(0xFF94A3B8))),
                                ),
                              ),
                            ),
                          ),
                          const Gap(4),
                          const Center(
                            child: Text(
                              'HANDOVER (Pre-Trip)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444), width: 2),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1583121274602-3e2820c69888',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFFEE2E2),
                                      child: const Center(child: Icon(Icons.car_crash_rounded, color: Color(0xFFEF4444))),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('NEW DAMAGE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(4),
                          const Center(
                            child: Text(
                              'RETURN (Post-Trip)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                SwitchListTile(
                  title: const Text('New Damage Spot Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('File an insurance/security claim for return damages', style: TextStyle(fontSize: 12)),
                  value: _newDamageDetected,
                  activeTrackColor: const Color(0xFFEF4444),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _newDamageDetected = val),
                ),
                if (_newDamageDetected) ...[
                  const Gap(8),
                  TextFormField(
                    controller: _newDamageNotesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Damage Assessment Description',
                      hintText: 'e.g. Scrape on lower bumper',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _claimAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Estimated Repair Claim Amount',
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Review(BookingModel booking) {
    final retOdo = double.tryParse(_returnOdometerCtrl.text) ?? 42681.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fact_check_rounded, color: Color(0xFF0066FF), size: 24),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Return Summary & Settlement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildSummaryRow('Customer', 'Rahul Sharma'),
                const Gap(8),
                _buildSummaryRow('Vehicle Plate', 'MH 12 CD 5678 (Creta SX)'),
                const Gap(8),
                _buildSummaryRow('Handover Odometer', '${_handoverOdometer.toInt()} km'),
                const Gap(8),
                _buildSummaryRow('Return Odometer', '${retOdo.toInt()} km'),
                const Gap(8),
                _buildSummaryRow('Total Distance Driven', '${_distanceDriven.toInt()} km'),
                const Gap(8),
                _buildSummaryRow('Fuel Return Level', '$_returnFuelPercent% (${_fuelDifference > 0 ? "-$_fuelDifference%" : "Full"})'),
                const Gap(8),
                _buildSummaryRow('Photo Burst', '4 Return Angles Verified'),
                const Gap(8),
                _buildSummaryRow(
                  'Damage Status',
                  _newDamageDetected ? '1 New Spot (Claim: ₹${_claimAmountCtrl.text})' : 'Clean (No New Damage)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ),
        const Gap(8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Back'),
              ),
              const Gap(12),
            ],
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3 ? const Color(0xFF10B981) : const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_currentStep < 3) {
                          if (_currentStep == 0) {
                            if (!_formKey.currentState!.validate()) return;
                          }
                          setState(() => _currentStep++);
                        } else {
                          _submitReturn();
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _currentStep == 3 ? 'COMPLETE RETURN' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialogDirect() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            Gap(10),
            Expanded(
              child: Text(
                'Return Completed',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle return and closing inspection verified. Security deposit settlement process initiated.',
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Final Odometer', '42,681 km (+291 km)'),
                  const Gap(6),
                  _buildSummaryRow('Return Fuel', '75% (-25% Refuel Charge)'),
                  const Gap(6),
                  _buildSummaryRow('Damage Claim', '₹1,500 Tagged'),
                  const Gap(6),
                  _buildSummaryRow('Inspection', '4/4 Photos Verified'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back to Operations'),
          ),
        ],
      ),
    );
  }
}
