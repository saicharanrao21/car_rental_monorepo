import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:intl/intl.dart';
import '../../../fleet/presentation/providers/fleet_providers.dart';
import '../providers/vendor_bookings_providers.dart';

class HandoverInspectionPage extends ConsumerStatefulWidget {
  final String bookingId;
  final int initialStep;
  final bool? hasDamage;
  final bool showSuccessDialog;
  final bool showOfflineDialog;

  const HandoverInspectionPage({
    super.key,
    required this.bookingId,
    this.initialStep = 0,
    this.hasDamage,
    this.showSuccessDialog = false,
    this.showOfflineDialog = false,
  });

  @override
  ConsumerState<HandoverInspectionPage> createState() => _HandoverInspectionPageState();
}

class _HandoverInspectionPageState extends ConsumerState<HandoverInspectionPage> {
  int _currentStep = 0; // 0: Identity, 1: Odo & Fuel, 2: 4-Photo Burst, 3: Damage, 4: Review
  final _formKey = GlobalKey<FormState>();

  // Verification
  bool _isCustomerVerified = true;
  bool _isLicenseVerified = true;

  // Odometer & Fuel
  final _odometerCtrl = TextEditingController(text: '42390');
  final double _lastRecordedOdometer = 42380.0;
  int _selectedFuelPercent = 100; // 0, 25, 50, 75, 100

  // 4-Photo Burst
  final Map<String, String> _burstPhotos = {
    'Front': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341',
    'Rear': 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
    'Left Side': 'https://images.unsplash.com/photo-1503376780353-7e6692767b70',
    'Right Side': 'https://images.unsplash.com/photo-1583121274602-3e2820c69888',
  };

  // Damage
  bool _hasDamage = false;
  String _selectedDamageLocation = 'Front Bumper';
  String _selectedDamageSeverity = 'Minor';
  final _damageNotesCtrl = TextEditingController();
  final List<Map<String, dynamic>> _recordedDamages = [];

  // Handover Confirmation
  final _handoverOtpCtrl = TextEditingController(text: '123456');
  bool _isSubmitting = false;
  bool _simulateOffline = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    if (widget.hasDamage == true) {
      _hasDamage = true;
      _recordedDamages.add({
        'location': 'Front Bumper',
        'severity': 'Minor Scuff',
        'notes': 'Pre-existing minor scratch near lower lip',
        'photo': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341',
      });
    }
    if (widget.showSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessDialogDirect();
      });
    }
    if (widget.showOfflineDialog) {
      _simulateOffline = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOfflineDialogDirect();
      });
    }
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _damageNotesCtrl.dispose();
    _handoverOtpCtrl.dispose();
    super.dispose();
  }

  Color _getFuelColor(int percent) {
    if (percent <= 25) return const Color(0xFFEF4444);
    if (percent <= 50) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String? _validateOdometer(String? val) {
    if (val == null || val.trim().isEmpty) return 'Enter odometer reading';
    final num = double.tryParse(val.trim());
    if (num == null || num <= 0) return 'Enter valid positive number';
    if (num < _lastRecordedOdometer) {
      return 'Reading cannot be less than last recorded (${_lastRecordedOdometer.toInt()} km)';
    }
    return null;
  }

  void _addDamageItem() {
    setState(() {
      _recordedDamages.add({
        'location': _selectedDamageLocation,
        'severity': _selectedDamageSeverity,
        'notes': _damageNotesCtrl.text.trim().isNotEmpty
            ? _damageNotesCtrl.text.trim()
            : 'Pre-existing minor surface blemish',
        'photo': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341',
      });
      _damageNotesCtrl.clear();
    });
  }

  Future<void> _submitHandover(BookingModel booking) async {
    if (_isSubmitting) return;

    final odo = double.tryParse(_odometerCtrl.text.trim()) ?? 42390.0;
    final otp = _handoverOtpCtrl.text.trim();
    if (otp.length != 6 || int.tryParse(otp) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please enter a valid 6-digit customer handover OTP.'),
        ),
      );
      return;
    }

    if (_simulateOffline) {
      // Save offline draft
      ref.read(offlineInspectionDraftsProvider.notifier).update((map) {
        final newMap = Map<String, Map<String, dynamic>>.from(map);
        newMap[widget.bookingId] = {
          'bookingId': widget.bookingId,
          'type': 'PRE_TRIP',
          'odometer': odo,
          'fuelPercent': _selectedFuelPercent,
          'photos': _burstPhotos.values.toList(),
          'damages': _recordedDamages,
          'timestamp': DateTime.now().toIso8601String(),
        };
        return newMap;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFF59E0B), size: 28),
              Gap(10),
              Text('Connection Lost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Handover inspection data has been safely cached on device. It will automatically sync once connection is restored.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B192C),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('Back to Bookings'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final damageList = _recordedDamages.map((d) => '${d['location']}: ${d['severity']} (${d['notes']})').toList();
    final photoList = _burstPhotos.values.toList();

    final success = await ref.read(vendorBookingsProvider.notifier).completeHandover(
      bookingId: widget.bookingId,
      odometer: odo,
      fuelPercent: _selectedFuelPercent,
      conditionNotes: damageList.join('; '),
      damagePhotos: photoList,
      handoverOtp: otp,
    );

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
              Text('Handover Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle has been successfully handed over to customer. Trip is now ACTIVE & ONGOING.',
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
                    _buildSummaryRow('Handover Odometer', '${odo.toInt()} km'),
                    const Gap(6),
                    _buildSummaryRow('Fuel Level', '$_selectedFuelPercent%'),
                    const Gap(6),
                    _buildSummaryRow('Inspection Burst', '4 Photos Verified'),
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
          content: Text('Failed to complete handover. Please check connection and try again.'),
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
          'Handover Inspection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _simulateOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: _simulateOffline ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            ),
            tooltip: _simulateOffline ? 'Offline Mode Active' : 'Online Mode',
            onPressed: () {
              setState(() {
                _simulateOffline = !_simulateOffline;
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(_simulateOffline ? 'Simulated Offline Mode Enabled' : 'Online Mode Restored'),
                ),
              );
            },
          ),
          const Gap(8),
        ],
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
                startDate: DateTime.now(),
                endDate: DateTime.now().add(const Duration(days: 3)),
                totalFare: 9600.0,
                platformFee: 960.0,
                gstAmount: 1728.0,
                netToVendor: 8640.0,
                status: 'confirmed',
                createdAt: DateTime.now().subtract(const Duration(hours: 4)),
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
                      if (_currentStep == 0) _buildStep0Identity(fallbackBooking),
                      if (_currentStep == 1) _buildStep1OdometerFuel(),
                      if (_currentStep == 2) _buildStep2PhotoBurst(),
                      if (_currentStep == 3) _buildStep3Damage(),
                      if (_currentStep == 4) _buildStep4Review(fallbackBooking),
                      const Gap(24),
                    ],
                  ),
                ),
              ),
              _buildBottomActionNav(fallbackBooking),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader() {
    final stepTitles = ['Identity', 'Odo & Fuel', '4-Photos', 'Damage', 'Review'];
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

  Widget _buildHandoverLocationBanner(BookingModel booking) {
    final isDoorstep = booking.deliveryType == 'DOORSTEP_DELIVERY' || booking.deliveryAddress != null;
    final isTransit = booking.deliveryType == 'PUBLIC_LOCATION' ||
        (booking.pickupHubId != null && booking.pickupHubId!.startsWith('pub_'));

    final locationTitle = booking.pickupName ?? (isDoorstep ? 'Customer Doorstep' : booking.pickupLocation);
    final locationAddress = isDoorstep
        ? (booking.deliveryAddress ?? booking.pickupAddress ?? booking.pickupLocation)
        : (booking.pickupAddress ?? booking.pickupLocation);

    final contextNote = isDoorstep
        ? 'Vehicle is being handed over at the customer\'s persisted delivery address.'
        : (isTransit
            ? 'Vehicle handover is at the selected public location.'
            : 'Vehicle handover at the vendor\'s selected operating yard.');

    final bannerBg = isDoorstep
        ? const Color(0xFFEEF2FF)
        : (isTransit ? const Color(0xFFFAF5FF) : const Color(0xFFF0FDF4));
    final bannerBorder = isDoorstep
        ? const Color(0xFFC7D2FE)
        : (isTransit ? const Color(0xFFE9D5FF) : const Color(0xFFBBF7D0));
    final titleColor = isDoorstep
        ? const Color(0xFF3730A3)
        : (isTransit ? const Color(0xFF6B21A8) : const Color(0xFF166534));
    final badgeLabel = isDoorstep ? 'DOORSTEP DISPATCH' : (isTransit ? 'TRANSIT HUB' : 'HOST YARD');
    final iconData = isDoorstep
        ? Icons.local_shipping_outlined
        : (isTransit ? Icons.connecting_airports_outlined : Icons.garage_outlined);

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
                        'HANDOVER LOCATION',
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

  Widget _buildStep0Identity(BookingModel booking) {
    final formatter = DateFormat('dd MMM, hh:mm a');

    final fleetCars = ref.watch(fleetCarsProvider).valueOrNull ?? [];
    final car = fleetCars.where((c) => c.id == booking.carId).firstOrNull;
    final vehicleModel = car != null ? '${car.make} ${car.model}' : (booking.carId.isNotEmpty ? 'Vehicle #${booking.carId.length > 8 ? booking.carId.substring(0, 8) : booking.carId}' : 'Assigned Vehicle');
    final plateNumber = car != null ? car.registrationNumber : (booking.carId.isNotEmpty ? 'ID: ${booking.carId}' : 'Unassigned');

    final customerName = booking.customerId == 'cust_101' || booking.customerId == 'cust_849201'
        ? 'Rahul Sharma'
        : (booking.customerId.isNotEmpty
            ? (booking.customerId.startsWith('cust_')
                ? 'Customer ${booking.customerId.toUpperCase()}'
                : 'Customer #${booking.customerId.length > 8 ? booking.customerId.substring(0, 8) : booking.customerId}')
            : 'Rahul Sharma');
    const customerPhone = '+91 98765 43210 • Verified License';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHandoverLocationBanner(booking),
        const Gap(14),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF0066FF), size: 24),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Text(
                            customerPhone,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'KYC VERIFIED',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaBlock('Vehicle Model', vehicleModel),
                    _buildMetaBlock('Plate Number', plateNumber),
                  ],
                ),
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaBlock('Pickup Time', formatter.format(booking.startDate)),
                    _buildMetaBlock('Trip Type', booking.tripType),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        const Text(
          'Verification Checkpoints',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(8),
        CheckboxListTile(
          value: _isCustomerVerified,
          activeColor: const Color(0xFF0066FF),
          title: const Text('Customer present in-person with valid Driving License', style: TextStyle(fontSize: 14)),
          onChanged: (val) => setState(() => _isCustomerVerified = val ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _isLicenseVerified,
          activeColor: const Color(0xFF0066FF),
          title: const Text('Vehicle registration plate matches booking manifest', style: TextStyle(fontSize: 14)),
          onChanged: (val) => setState(() => _isLicenseVerified = val ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildStep1OdometerFuel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Odometer Reading',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Last: ${_lastRecordedOdometer.toInt()} km',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                TextFormField(
                  controller: _odometerCtrl,
                  keyboardType: TextInputType.number,
                  validator: _validateOdometer,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                  decoration: InputDecoration(
                    suffixText: 'KM',
                    suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('+10 km'),
                      onPressed: () {
                        final curr = double.tryParse(_odometerCtrl.text) ?? _lastRecordedOdometer;
                        _odometerCtrl.text = (curr + 10).toInt().toString();
                      },
                    ),
                    ActionChip(
                      label: const Text('+50 km'),
                      onPressed: () {
                        final curr = double.tryParse(_odometerCtrl.text) ?? _lastRecordedOdometer;
                        _odometerCtrl.text = (curr + 50).toInt().toString();
                      },
                    ),
                    ActionChip(
                      label: const Text('+100 km'),
                      onPressed: () {
                        final curr = double.tryParse(_odometerCtrl.text) ?? _lastRecordedOdometer;
                        _odometerCtrl.text = (curr + 100).toInt().toString();
                      },
                    ),
                  ],
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
                      child: Text(
                        'Fuel Level Indicator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      '$_selectedFuelPercent%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getFuelColor(_selectedFuelPercent),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _selectedFuelPercent / 100.0,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(_getFuelColor(_selectedFuelPercent)),
                  ),
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0, 25, 50, 75, 100].map((val) {
                    final isSelected = _selectedFuelPercent == val;
                    final label = val == 0 ? 'E' : val == 100 ? 'F' : '$val%';

                    return InkWell(
                      onTap: () => setState(() => _selectedFuelPercent = val),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2PhotoBurst() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4-Angle Mandatory Inspection Burst',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Text(
          'Capture all 4 angles while standing directly next to vehicle.',
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
          children: _burstPhotos.entries.map((entry) {
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
              children: [
                Expanded(
                  child: Text(
                    angleName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B192C)),
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Retake $angleName photo')),
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

  Widget _buildStep3Damage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Damage Assessment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Text(
          'Record any pre-existing scratches, dents, or wear prior to customer departure.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_hasDamage ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                  foregroundColor: !_hasDamage ? Colors.white : const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('No Pre-Existing Damage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => setState(() => _hasDamage = false),
              ),
            ),
            const Gap(12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasDamage ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                  foregroundColor: _hasDamage ? Colors.white : const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Add Damage Spot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => setState(() => _hasDamage = true),
              ),
            ),
          ],
        ),
        if (_hasDamage) ...[
          const Gap(16),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Damage Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Gap(8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ['Front Bumper', 'Rear Bumper', 'Left Door', 'Right Door', 'Windshield', 'Wheels', 'Roof']
                        .map((loc) => ChoiceChip(
                              label: Text(loc),
                              selected: _selectedDamageLocation == loc,
                              onSelected: (_) => setState(() => _selectedDamageLocation = loc),
                            ))
                        .toList(),
                  ),
                  const Gap(14),
                  const Text('Severity Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Gap(8),
                  Wrap(
                    spacing: 8,
                    children: ['Minor (Scratch)', 'Moderate (Dent)', 'Major (Structural)']
                        .map((sev) => ChoiceChip(
                              label: Text(sev),
                              selected: _selectedDamageSeverity == sev.split(' ').first,
                              onSelected: (_) => setState(() => _selectedDamageSeverity = sev.split(' ').first),
                            ))
                        .toList(),
                  ),
                  const Gap(14),
                  TextFormField(
                    controller: _damageNotesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Damage Description Notes',
                      hintText: 'e.g. 2-inch scratch on lower left bumper',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B192C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Save Damage Item'),
                      onPressed: _addDamageItem,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_recordedDamages.isNotEmpty) ...[
          const Gap(16),
          const Text('Recorded Damage Spots', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Gap(8),
          ..._recordedDamages.map((d) => AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.car_crash_outlined, color: Color(0xFFEF4444)),
                  title: Text('${d['location']} • ${d['severity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(d['notes'] as String),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildStep4Review(BookingModel booking) {
    final odo = double.tryParse(_odometerCtrl.text) ?? 42390.0;
    final fleetCars = ref.watch(fleetCarsProvider).valueOrNull ?? [];
    final car = fleetCars.where((c) => c.id == booking.carId).firstOrNull;
    final vehicleModel = car != null ? '${car.make} ${car.model}' : (booking.carId.isNotEmpty ? 'Vehicle #${booking.carId.length > 8 ? booking.carId.substring(0, 8) : booking.carId}' : 'Assigned Vehicle');
    final plateNumber = car != null ? car.registrationNumber : (booking.carId.isNotEmpty ? 'ID: ${booking.carId}' : 'Unassigned');

    final customerName = booking.customerId == 'cust_101' || booking.customerId == 'cust_849201'
        ? 'Rahul Sharma'
        : (booking.customerId.isNotEmpty
            ? (booking.customerId.startsWith('cust_')
                ? 'Customer ${booking.customerId.toUpperCase()}'
                : 'Customer #${booking.customerId.length > 8 ? booking.customerId.substring(0, 8) : booking.customerId}')
            : 'Rahul Sharma');

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
                    Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0066FF), size: 24),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Handover Summary Review',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildSummaryRow('Customer', '$customerName (+91 98765 43210)'),
                const Gap(8),
                _buildSummaryRow('Vehicle Plate', '$plateNumber ($vehicleModel)'),
                const Gap(8),
                _buildSummaryRow('Departure Odometer', '${odo.toInt()} km'),
                const Gap(8),
                _buildSummaryRow('Departure Fuel', '$_selectedFuelPercent% Level'),
                const Gap(8),
                _buildSummaryRow('Photo Burst', '4/4 Angles Captured & Stored'),
                const Gap(8),
                _buildSummaryRow(
                  'Damage Status',
                  _recordedDamages.isEmpty ? 'Clean (No Pre-Existing Damage)' : '${_recordedDamages.length} Spots Recorded',
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
                const Text('Customer Handover OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Gap(4),
                const Text('Enter 6-digit OTP provided by customer at vehicle pickup:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const Gap(12),
                TextFormField(
                  controller: _handoverOtpCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  obscuringCharacter: '•',
                  maxLength: 6,
                  style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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

  Widget _buildMetaBlock(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const Gap(2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionNav(BookingModel booking) {
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
                  backgroundColor: _currentStep == 4 ? const Color(0xFF10B981) : const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_currentStep < 4) {
                          if (_currentStep == 1) {
                            if (!_formKey.currentState!.validate()) return;
                          }
                          setState(() => _currentStep++);
                        } else {
                          _submitHandover(booking);
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _currentStep == 4 ? 'COMPLETE HANDOVER' : 'Continue',
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
                'Handover Completed',
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
              'Vehicle has been successfully handed over to customer. Trip is now ACTIVE & ONGOING.',
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
                  _buildSummaryRow('Handover Odometer', '42,390 km'),
                  const Gap(6),
                  _buildSummaryRow('Fuel Level', '100% Full'),
                  const Gap(6),
                  _buildSummaryRow('Inspection Burst', '4 Photos Verified'),
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

  void _showOfflineDialogDirect() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFF59E0B), size: 28),
            Gap(10),
            Expanded(
              child: Text(
                'Connection Lost',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Handover inspection data has been safely cached on device. It will automatically sync once connection is restored.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B192C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back to Bookings'),
          ),
        ],
      ),
    );
  }
}
