import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/locations_providers.dart';

class AddLocationWizardPage extends ConsumerStatefulWidget {
  final int initialStep;
  const AddLocationWizardPage({super.key, this.initialStep = 0});

  @override
  ConsumerState<AddLocationWizardPage> createState() => _AddLocationWizardPageState();
}

class _AddLocationWizardPageState extends ConsumerState<AddLocationWizardPage> {
  late int _currentStep;
  final int _totalSteps = 8;
  bool _isSubmitting = false;

  // Step 1: Location Type
  VendorLocationType _selectedType = VendorLocationType.vendorYard;

  // Step 2: Location Details
  final _nameCtrl = TextEditingController(text: 'Gachibowli Operational Yard');
  final _addressCtrl = TextEditingController(text: 'Plot 108, Financial District, Gachibowli');
  final _localityCtrl = TextEditingController(text: 'Gachibowli');
  final _cityCtrl = TextEditingController(text: 'Hyderabad');
  final _stateCtrl = TextEditingController(text: 'Telangana');
  final _pincodeCtrl = TextEditingController(text: '500032');
  final _contactPhoneCtrl = TextEditingController(text: '+91 98765 43213');

  // Step 3: Map / Coordinates
  final double _latitude = 17.4401;
  final double _longitude = 78.3489;

  // Step 4: Operating Hours
  bool _is24x7 = false;
  final String _openingTime = '08:00';
  final String _closingTime = '22:00';

  // Step 5: Capabilities
  bool _allowsPickup = true;
  bool _allowsReturn = true;
  bool _allowsDelivery = true;

  // Step 6: Pricing / Fees
  double _pickupFee = 0.0;
  final double _returnFee = 0.0;
  double _oneWayFee = 200.0;

  // Step 7: Vehicle Assignment
  final Set<String> _selectedCarIds = {'car_1', 'car_2'};

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _localityCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitLocation();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _submitLocation() async {
    setState(() => _isSubmitting = true);
    final newLocation = VendorLocationModel(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: 'v_1',
      name: _nameCtrl.text.trim().isEmpty ? 'Gachibowli Yard' : _nameCtrl.text.trim(),
      type: _selectedType,
      address: _addressCtrl.text.trim(),
      locality: _localityCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? 'Hyderabad' : _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim().isEmpty ? 'Telangana' : _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      contactPhone: _contactPhoneCtrl.text.trim(),
      status: VendorLocationStatus.active,
      allowsPickup: _allowsPickup,
      allowsReturn: _allowsReturn,
      allowsDelivery: _allowsDelivery,
      pickupFee: _pickupFee,
      returnFee: _returnFee,
      oneWayFee: _oneWayFee,
      openingTime: _openingTime,
      closingTime: _closingTime,
      is24x7: _is24x7,
      serviceRadiusKm: 25.0,
      assignedCarCount: _selectedCarIds.length,
      assignedCarIds: _selectedCarIds.toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(vendorLocationsProvider.notifier).addLocation(newLocation);
    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF059669), size: 28),
            Gap(10),
            Text('Location Activated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_nameCtrl.text} has been activated and is now ready for customer bookings.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Type: ${_selectedType.displayName}\n'
                'Vehicles Assigned: ${_selectedCarIds.length} cars\n'
                'Pickup: ${_allowsPickup ? "✓ Enabled" : "✗ Disabled"}\n'
                'Return: ${_allowsReturn ? "✓ Enabled" : "✗ Disabled"}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('VIEW ALL LOCATIONS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle(_currentStep)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B192C),
        elevation: 0,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildStepContent(_currentStep),
            ),
          ),
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Location Type';
      case 1:
        return 'Location Details';
      case 2:
        return 'Map & Coordinates';
      case 3:
        return 'Operating Hours';
      case 4:
        return 'Capabilities';
      case 5:
        return 'Pricing & Fees';
      case 6:
        return 'Vehicle Assignment';
      case 7:
        return 'Review & Activate';
      default:
        return 'Location Setup';
    }
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildStep0LocationType();
      case 1:
        return _buildStep1LocationDetails();
      case 2:
        return _buildStep2MapCoordinates();
      case 3:
        return _buildStep3OperatingHours();
      case 4:
        return _buildStep4Capabilities();
      case 5:
        return _buildStep5PricingFees();
      case 6:
        return _buildStep6VehicleAssignment();
      case 7:
        return _buildStep7ReviewActivate();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0LocationType() {
    final types = [
      (VendorLocationType.vendorYard, 'Vendor Yard / Garage', 'Primary operational base for vehicle storage and maintenance', Icons.garage_outlined),
      (VendorLocationType.branch, 'Branch Hub', 'Secondary branch office with dedicated pickup parking', Icons.domain_outlined),
      (VendorLocationType.airport, 'Airport Terminal', 'Designated airport parking counter for inbound travelers', Icons.local_airport_outlined),
      (VendorLocationType.railwayStation, 'Railway Station', 'Convenient transport meeting point at station arrival gates', Icons.train_outlined),
      (VendorLocationType.publicPoint, 'Public Meeting Point', 'Verified metro station or commercial mall hub', Icons.place_outlined),
      (VendorLocationType.office, 'Commercial Office', 'Business park or corporate center handover point', Icons.business_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Location Category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Choose the operational nature of this handover and drop-off facility.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        ...types.map((item) {
          final isSelected = _selectedType == item.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedType = item.$1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0066FF).withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0066FF).withValues(alpha: 0.15)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.$4, color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF64748B), size: 22),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF0B192C),
                            ),
                          ),
                          const Gap(2),
                          Text(
                            item.$3,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep1LocationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Address & Contact',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Provide clear, recognizable address details for customers during booking.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        _buildTextField('Location Display Name *', _nameCtrl, 'e.g. Hyderabad Main Yard'),
        const Gap(14),
        _buildTextField('Street / Area Address *', _addressCtrl, 'e.g. Plot 42, Madhapur, Hitec City'),
        const Gap(14),
        Row(
          children: [
            Expanded(child: _buildTextField('Locality *', _localityCtrl, 'e.g. Madhapur')),
            const Gap(12),
            Expanded(child: _buildTextField('City *', _cityCtrl, 'e.g. Hyderabad')),
          ],
        ),
        const Gap(14),
        Row(
          children: [
            Expanded(child: _buildTextField('State *', _stateCtrl, 'e.g. Telangana')),
            const Gap(12),
            Expanded(child: _buildTextField('PIN Code *', _pincodeCtrl, 'e.g. 500081')),
          ],
        ),
        const Gap(14),
        _buildTextField('Yard Manager / Contact Phone *', _contactPhoneCtrl, 'e.g. +91 98765 43210'),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const Gap(6),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2MapCoordinates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Map Selection & GPS Pinpoint',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Accurate coordinates ensure customers navigate directly to the vehicle bay.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Stack(
            children: [
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, size: 48, color: Color(0xFF0066FF)),
                    Gap(6),
                    Text(
                      'Latitude: 17.4401 • Longitude: 78.3489',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
                    ),
                    Gap(2),
                    Text(
                      'Financial District, Gachibowli, Hyderabad',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('GPS coordinates updated from device location.')),
                    );
                  },
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use Current Location', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0066FF),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LATITUDE', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    const Gap(4),
                    Text('$_latitude', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LONGITUDE', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    const Gap(4),
                    Text('$_longitude', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3OperatingHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operating Hours & Schedule',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Configure when customers can pick up or drop off vehicles at this location.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('24x7 Continuous Operations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Gap(2),
                  Text('Open all day and night for round-the-clock service', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
              ),
              Switch(
                value: _is24x7,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (val) => setState(() => _is24x7 = val),
              ),
            ],
          ),
        ),
        if (!_is24x7) ...[
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OPENING TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const Gap(6),
                      Text(_openingTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CLOSING TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const Gap(6),
                      Text(_closingTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep4Capabilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Capabilities',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Select which operations are enabled at this specific location.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        _buildCapabilitySwitch(
          'Allow Vehicle Pickup',
          'Customers can initiate bookings and collect vehicles here',
          _allowsPickup,
          (v) => setState(() => _allowsPickup = v),
          Icons.key,
        ),
        const Gap(12),
        _buildCapabilitySwitch(
          'Allow Vehicle Return / Drop-Off',
          'Customers can conclude trips and return vehicles here',
          _allowsReturn,
          (v) => setState(() => _allowsReturn = v),
          Icons.assignment_turned_in,
        ),
        const Gap(12),
        _buildCapabilitySwitch(
          'Doorstep Delivery Hub',
          'Use this location as origin for customer address dispatch',
          _allowsDelivery,
          (v) => setState(() => _allowsDelivery = v),
          Icons.delivery_dining,
        ),
      ],
    );
  }

  Widget _buildCapabilitySwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0066FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0066FF), size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                const Gap(2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF059669),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStep5PricingFees() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing & Surcharges',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Configure transparent, auditable fees for premium location handovers.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        _buildFeeCard('Pickup Convenience Fee', 'Extra fee for airport parking or terminal access', _pickupFee, (v) => setState(() => _pickupFee = v)),
        const Gap(12),
        _buildFeeCard('One-Way Relocation Surcharge', 'Charged when customer returns to a different location', _oneWayFee, (v) => setState(() => _oneWayFee = v)),
      ],
    );
  }

  Widget _buildFeeCard(String title, String desc, double value, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              Text('₹${value.toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
            ],
          ),
          const Gap(4),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const Gap(10),
          Slider(
            value: value,
            min: 0,
            max: 1000,
            divisions: 20,
            activeColor: const Color(0xFF0066FF),
            label: '₹${value.toInt()}',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStep6VehicleAssignment() {
    final availableFleet = [
      ('car_1', 'Hyundai Creta SX(O)', 'MH 12 CD 5678', 'SUV • Diesel'),
      ('car_2', 'Mahindra Thar 4x4', 'TS 09 EA 1001', 'SUV • Diesel'),
      ('car_3', 'Tata Nexon EV', 'TS 09 EA 2002', 'Compact SUV • Electric'),
      ('car_4', 'Maruti Swift ZXi', 'MH 02 EF 4321', 'Hatchback • Petrol'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign Vehicles to Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Select which vehicles will be primarily stationed at this facility.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        ...availableFleet.map((car) {
          final isSelected = _selectedCarIds.contains(car.$1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CheckboxListTile(
              value: isSelected,
              activeColor: const Color(0xFF0066FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
              tileColor: Colors.white,
              title: Text(car.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text('${car.$3} • ${car.$4}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedCarIds.add(car.$1);
                  } else {
                    _selectedCarIds.remove(car.$1);
                  }
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep7ReviewActivate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Activate Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
        ),
        const Gap(6),
        const Text(
          'Review configuration before publishing this location to customer discovery.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Gap(16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Location Name', _nameCtrl.text),
              const Divider(height: 16),
              _buildReviewRow('Type', _selectedType.displayName),
              const Divider(height: 16),
              _buildReviewRow('Address', '${_addressCtrl.text}, ${_cityCtrl.text}'),
              const Divider(height: 16),
              _buildReviewRow('Coordinates', '$_latitude, $_longitude'),
              const Divider(height: 16),
              _buildReviewRow('Hours', _is24x7 ? '24x7 Continuous' : '$_openingTime - $_closingTime'),
              const Divider(height: 16),
              _buildReviewRow('Pickup / Return', '${_allowsPickup ? "Pickup ✓" : ""} ${_allowsReturn ? "Return ✓" : ""}'),
              const Divider(height: 16),
              _buildReviewRow('Assigned Vehicles', '${_selectedCarIds.length} cars'),
              const Divider(height: 16),
              _buildReviewRow('One-Way Fee', '₹${_oneWayFee.toInt()}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B192C)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_currentStep == 0 ? 'CANCEL' : 'BACK'),
            ),
          ),
          const Gap(12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep == _totalSteps - 1 ? 'ACTIVATE LOCATION' : 'CONTINUE'),
            ),
          ),
        ],
      ),
    );
  }
}
