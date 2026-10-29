import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/fleet_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';
import '../../../../core/providers/api_providers.dart';

class AddEditCarPage extends ConsumerStatefulWidget {
  final String? carId;
  final List<String>? initialPhotos;
  final String? initialHubId;
  final String? initialHubName;

  const AddEditCarPage({
    super.key,
    this.carId,
    this.initialPhotos,
    this.initialHubId,
    this.initialHubName,
  });

  @override
  ConsumerState<AddEditCarPage> createState() => _AddEditCarPageState();
}

class _AddEditCarPageState extends ConsumerState<AddEditCarPage> {
  int _currentStep = 0;
  final int _totalSteps = 6;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;

  bool get isEditMode => widget.carId != null && widget.carId!.isNotEmpty;

  // Controllers
  late TextEditingController _makeCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _variantCtrl;
  late TextEditingController _regNumCtrl;
  late TextEditingController _seatingCtrl;
  late TextEditingController _priceDayCtrl;
  late TextEditingController _priceHourCtrl;
  late TextEditingController _priceKmCtrl;

  // Specifications
  int? _selectedYear;
  String? _selectedCategory;
  String? _selectedFuelType;
  String _selectedTransmission = 'Automatic';
  bool _isAC = true;
  List<String> _selectedTripTypes = [];
  List<String> _photos = [];
  String? _selectedHubId;
  String? _selectedHubName;
  bool _isAvailableOnPublish = true;

  late List<int> _years;

  @override
  void initState() {
    super.initState();

    final currentYear = DateTime.now().year;
    _years = List.generate(15, (index) => currentYear - index);

    _makeCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _variantCtrl = TextEditingController(text: 'ZXi+');
    _regNumCtrl = TextEditingController();
    _seatingCtrl = TextEditingController(text: '5');
    _priceDayCtrl = TextEditingController(text: '2400');
    _priceHourCtrl = TextEditingController(text: '180');
    _priceKmCtrl = TextEditingController(text: '14');

    if (isEditMode) {
      final carsList = ref.read(fleetCarsProvider).value ?? [];
      final car = carsList.firstWhere(
        (c) => c.id == widget.carId,
        orElse: () => const CarModel(
          id: '',
          vendorId: '',
          make: '',
          model: '',
          year: 2023,
          type: 'Sedan',
          fuelType: 'Petrol',
          seating: 5,
          isAC: true,
          photos: [],
          pricePerKm: 14,
          pricePerDay: 2400,
          pricePerHour: 180,
        ),
      );

      if (car.id.isNotEmpty) {
        _makeCtrl.text = car.make;
        _modelCtrl.text = car.model;
        _regNumCtrl.text = car.registrationNumber;
        _seatingCtrl.text = car.seating.toString();
        _priceDayCtrl.text = car.pricePerDay.toStringAsFixed(0);
        _priceHourCtrl.text = car.pricePerHour.toStringAsFixed(0);
        _priceKmCtrl.text = car.pricePerKm.toStringAsFixed(0);
        _selectedYear = car.year;
        _selectedCategory = car.type;
        _selectedFuelType = car.fuelType;
        _isAC = car.isAC;
        _selectedTripTypes = List.from(car.availableTripTypes);
        _photos = List.from(car.photos);
        _isAvailableOnPublish = car.isAvailable;
        _selectedHubId = car.pickupHubId;
      }
    } else {
      _selectedYear = currentYear;
      _selectedCategory = 'Sedan';
      _selectedFuelType = 'Petrol';
      _selectedTripTypes = ['Self-Drive', 'Outstation', 'Local', 'Airport Transfer'];
      _photos = widget.initialPhotos != null ? List.from(widget.initialPhotos!) : []; // Authentic photos required - zero sample photos!
      _selectedHubId = widget.initialHubId;
      _selectedHubName = widget.initialHubName;
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _variantCtrl.dispose();
    _regNumCtrl.dispose();
    _seatingCtrl.dispose();
    _priceDayCtrl.dispose();
    _priceHourCtrl.dispose();
    _priceKmCtrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_makeCtrl.text.trim().isEmpty) {
        _showError('Please enter the vehicle manufacturer/make (e.g. Hyundai, Tata)');
        return false;
      }
      if (_modelCtrl.text.trim().isEmpty) {
        _showError('Please enter the vehicle model (e.g. Creta, Swift)');
        return false;
      }
      if (_regNumCtrl.text.trim().isEmpty) {
        _showError('Please enter registration plate number (e.g. MH 12 AB 1234)');
        return false;
      }
    } else if (step == 1) {
      if (_selectedYear == null) {
        _showError('Please select manufacturing year');
        return false;
      }
      if (_selectedCategory == null) {
        _showError('Please select body category');
        return false;
      }
      if (_selectedFuelType == null) {
        _showError('Please select powertrain fuel type');
        return false;
      }
      final seats = int.tryParse(_seatingCtrl.text.trim());
      if (seats == null || seats <= 0) {
        _showError('Please enter valid seating capacity');
        return false;
      }
    } else if (step == 2) {
      final priceDay = double.tryParse(_priceDayCtrl.text.trim());
      final priceHour = double.tryParse(_priceHourCtrl.text.trim());
      final priceKm = double.tryParse(_priceKmCtrl.text.trim());
      if (priceDay == null || priceDay <= 0) {
        _showError('Daily rental price must be greater than 0');
        return false;
      }
      if (priceHour == null || priceHour <= 0) {
        _showError('Hourly rental rate must be greater than 0');
        return false;
      }
      if (priceKm == null || priceKm <= 0) {
        _showError('Per km rate must be greater than 0');
        return false;
      }
    } else if (step == 3) {
      if (_photos.isEmpty) {
        _showError('Please upload at least 1 authentic vehicle photo before continuing.');
        return false;
      }
    } else if (step == 4) {
      if (_selectedHubId == null || _selectedHubId!.isEmpty) {
        _showError('Please select or register an operating yard for vehicle pickup.');
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.split('.').last.toLowerCase();
      String contentType = 'image/jpeg';
      if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      }

      final uploadService = UploadService(apiClient: ref.read(apiClientProvider));
      final result = await uploadService.uploadFileBytes(
        fileType: 'car-photo',
        contentType: contentType,
        fileBytes: bytes,
      );

      final photoUrl = result.publicUrl ?? result.uploadUrl;
      if (mounted) {
        setState(() {
          _photos.add(photoUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle photo uploaded successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Photo upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Vehicle Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Gap(8),
              const Text(
                'Choose authentic photos of your actual vehicle (front, back, interior).',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture live exterior or interior photo', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select existing vehicle photo from device', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddHubDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String selectedCity = 'Hyderabad';
    final supportedCitiesAsync = ref.read(supportedCitiesProvider);
    final cities = supportedCitiesAsync.value ?? ['Hyderabad', 'Bengaluru', 'Mumbai', 'Delhi-NCR', 'Pune'];
    if (!cities.contains(selectedCity) && cities.isNotEmpty) {
      selectedCity = cities.first;
    }
    bool isSavingHub = false;

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Operating Yard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yard / Hub Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(4),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Madhapur Central Yard',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Gap(12),
                    const Text('Operating City *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(4),
                    DropdownButtonFormField<String>(
                      value: selectedCity,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedCity = val);
                      },
                    ),
                    const Gap(12),
                    const Text('Physical Address *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Gap(4),
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Plot 12, Hitec City Main Road',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingHub ? null : () => Navigator.of(dlgContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSavingHub
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final address = addressCtrl.text.trim();
                          if (name.isEmpty || address.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter yard name and physical address'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          setDlgState(() => isSavingHub = true);
                          try {
                            final client = ref.read(apiClientProvider).dio;
                            final res = await client.post('/locations/hubs', data: {
                              'name': name,
                              'address': address,
                              'city': selectedCity,
                              'latitude': 17.4482,
                              'longitude': 78.3914,
                              'serviceRadiusKm': 25,
                            });
                            final newHub = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
                            ref.invalidate(vendorPickupHubsProvider);
                            if (newHub != null && newHub['id'] != null) {
                              setState(() {
                                _selectedHubId = newHub['id'].toString();
                                _selectedHubName = newHub['name']?.toString() ?? name;
                              });
                            }
                            if (Navigator.of(dlgContext).canPop()) {
                              Navigator.of(dlgContext).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Operating yard registered successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (err) {
                            setDlgState(() => isSavingHub = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to register yard: $err'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSavingHub
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Register Yard'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onNextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _submitCar();
      }
    }
  }

  void _onPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _submitCar() async {
    if (_photos.isEmpty) {
      _showError('Please upload at least 1 authentic vehicle photo before publishing.');
      setState(() => _currentStep = 3);
      return;
    }
    if (_selectedHubId == null || _selectedHubId!.isEmpty) {
      _showError('Please select or register an operating yard for vehicle pickup.');
      setState(() => _currentStep = 4);
      return;
    }

    setState(() => _isSubmitting = true);

    final vendorId = ref.read(vendorSessionProvider).vendor?.id ?? '';
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final regNum = _regNumCtrl.text.trim().toUpperCase();
    final seating = int.tryParse(_seatingCtrl.text.trim()) ?? 5;
    final priceDay = double.tryParse(_priceDayCtrl.text.trim()) ?? 2000.0;
    final priceHour = double.tryParse(_priceHourCtrl.text.trim()) ?? 150.0;
    final priceKm = double.tryParse(_priceKmCtrl.text.trim()) ?? 12.0;

    final carData = CarModel(
      id: widget.carId ?? '',
      vendorId: vendorId,
      make: make,
      model: model,
      year: _selectedYear ?? DateTime.now().year,
      type: _selectedCategory ?? 'Sedan',
      fuelType: _selectedFuelType ?? 'Petrol',
      seating: seating,
      isAC: _isAC,
      photos: _photos,
      pricePerKm: priceKm,
      pricePerDay: priceDay,
      pricePerHour: priceHour,
      registrationNumber: regNum,
      availableTripTypes: _selectedTripTypes.isNotEmpty ? _selectedTripTypes : ['Local', 'Outstation'],
      isAvailable: _isAvailableOnPublish,
      pickupHubId: _selectedHubId,
    );

    final fleetController = ref.read(fleetControllerProvider.notifier);
    bool success = false;
    try {
      if (isEditMode) {
        success = await fleetController.updateCar(carData).timeout(const Duration(seconds: 15));
      } else {
        success = await fleetController.addCar(carData).timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Vehicle submission timed out after 15 seconds. Please check your network or try again.');
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Submission error: $e');
        return;
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode
                ? 'Vehicle updated successfully'
                : 'Vehicle submitted for admin review! (Draft / Pending Verification)'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        final error = ref.read(fleetControllerProvider).error;
        final errorMsg = error != null
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to save vehicle. Please check network/server logs.';
        _showError(errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Vehicle' : 'Fast Add Vehicle',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Step Progress Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'STEP ${_currentStep + 1} OF $_totalSteps: ${_getStepTitle(_currentStep).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${((_currentStep + 1) / _totalSteps * 100).toInt()}% Done',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),

              // Active Step Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStepWidget(),
                ),
              ),

              // Bottom Navigation Actions
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _onPreviousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const Gap(12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _onNextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _currentStep == _totalSteps - 1
                              ? (isEditMode ? 'Save Changes' : 'Publish Vehicle')
                              : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(child: AppLoader()),
            ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Vehicle Identity';
      case 1:
        return 'Specifications';
      case 2:
        return 'Commercial & Pricing';
      case 3:
        return 'Media & Photos';
      case 4:
        return 'Pickup & Operations';
      case 5:
        return 'Review & Publish';
      default:
        return '';
    }
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Specifications();
      case 2:
        return _buildStep3Commercial();
      case 3:
        return _buildStep4Media();
      case 4:
        return _buildStep5Operations();
      case 5:
        return _buildStep6Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: IDENTITY
  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Identification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Gap(4),
        const Text(
          'Enter basic identity details of the car as per the registration documents.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const Gap(20),

        _buildTextField(
          controller: _makeCtrl,
          label: 'Manufacturer / Brand *',
          hint: 'e.g. Maruti Suzuki, Hyundai, Tata',
          icon: Icons.directions_car_rounded,
        ),
        const Gap(16),

        _buildTextField(
          controller: _modelCtrl,
          label: 'Model Name *',
          hint: 'e.g. Swift, Creta, Nexon, Thar',
          icon: Icons.label_outline_rounded,
        ),
        const Gap(16),

        _buildTextField(
          controller: _variantCtrl,
          label: 'Variant / Trim',
          hint: 'e.g. ZXi+, SX(O), Creative',
          icon: Icons.tune_rounded,
        ),
        const Gap(16),

        _buildTextField(
          controller: _regNumCtrl,
          label: 'Registration Plate Number *',
          hint: 'e.g. MH 12 AB 1234',
          icon: Icons.pin_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  // STEP 2: SPECIFICATIONS
  Widget _buildStep2Specifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Technical Specifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Gap(4),
        const Text(
          'Specify body category, powertrain, transmission, and seating layout.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const Gap(20),

        // Year dropdown
        const Text('Manufacturing Year *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Gap(6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              isExpanded: true,
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
              onChanged: (val) => setState(() => _selectedYear = val),
            ),
          ),
        ),
        const Gap(16),

        // Category dropdown
        const Text('Body / Vehicle Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Gap(6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: ['Hatchback', 'Sedan', 'SUV', 'Luxury', 'Tempo Traveller', 'Mini Bus']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
          ),
        ),
        const Gap(16),

        // Fuel Type
        const Text('Fuel Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Petrol', 'Diesel', 'Electric', 'CNG', 'Hybrid'].map((fuel) {
            final isSelected = _selectedFuelType == fuel;
            return ChoiceChip(
              label: Text(fuel),
              selected: isSelected,
              selectedColor: const Color(0xFFEEF2FF),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedFuelType = fuel);
              },
            );
          }).toList(),
        ),
        const Gap(16),

        // Transmission
        const Text('Transmission *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Gap(8),
        Row(
          children: ['Automatic', 'Manual'].map((trans) {
            final isSelected = _selectedTransmission == trans;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Center(child: Text(trans)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFEEF2FF),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedTransmission = trans);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const Gap(16),

        // Seating & AC
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _seatingCtrl,
                label: 'Seating Capacity *',
                hint: '5',
                icon: Icons.airline_seat_recline_normal_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 22),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Air Conditioned',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isAC,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setState(() => _isAC = val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3: COMMERCIAL & PRICING
  Widget _buildStep3Commercial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Commercial Rates & Pricing',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Gap(4),
        const Text(
          'Set daily, hourly, and per-km pricing for customer bookings.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const Gap(16),

        // Phase 35 Canonical Pricing Governance Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
              Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server-Authoritative Pricing Active',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    Gap(2),
                    Text(
                      'Base rates set here establish future vehicle quotes. Applicable taxes (GST), platform fees, and security deposits are authoritatively calculated at checkout. Changes will not alter existing accepted bookings or quotes.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        _buildTextField(
          controller: _priceDayCtrl,
          label: 'Daily Rental Price (₹/day) *',
          hint: 'e.g. 2400',
          icon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
        ),
        const Gap(16),

        _buildTextField(
          controller: _priceHourCtrl,
          label: 'Hourly Rate (₹/hour) *',
          hint: 'e.g. 180',
          icon: Icons.schedule_rounded,
          keyboardType: TextInputType.number,
        ),
        const Gap(16),

        _buildTextField(
          controller: _priceKmCtrl,
          label: 'Excess Mileage Rate (₹/km) *',
          hint: 'e.g. 14',
          icon: Icons.speed_rounded,
          keyboardType: TextInputType.number,
        ),
        const Gap(20),

        const Text('Supported Trip Types *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Local', 'Outstation', 'Airport Transfer', 'Self-Drive'].map((trip) {
            final isSelected = _selectedTripTypes.contains(trip);
            return FilterChip(
              label: Text(trip),
              selected: isSelected,
              selectedColor: const Color(0xFFEEF2FF),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedTripTypes.add(trip);
                  } else {
                    _selectedTripTypes.remove(trip);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // STEP 4: MEDIA & PHOTOS
  Widget _buildStep4Media() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Media & Gallery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Gap(4),
                Text(
                  'Upload genuine photos of your vehicle (min. 1 required).',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            if (_photos.isNotEmpty)
              TextButton.icon(
                onPressed: _isUploadingPhoto ? null : _showPhotoSourceSheet,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('Add More'),
              ),
          ],
        ),
        const Gap(16),

        // Quality Guidance Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
              Gap(10),
              Expanded(
                child: Text(
                  'Stock photos and sample placeholders are strictly rejected by Admin verification. The first photo will be used as the listing cover.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        if (_photos.isEmpty)
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  _isUploadingPhoto
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.primary),
                  const Gap(12),
                  Text(
                    _isUploadingPhoto ? 'Uploading to secure storage...' : 'Tap to Upload Real Vehicle Photos',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const Gap(4),
                  const Text(
                    'High quality front, rear, and interior photos required',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._photos.asMap().entries.map((entry) {
                final idx = entry.key;
                final photoUrl = entry.value;
                final isCover = idx == 0;
                return Stack(
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCover ? AppColors.primary : const Color(0xFFCBD5E1),
                          width: isCover ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isCover)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COVER',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _photos.removeAt(idx);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_isUploadingPhoto)
                Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _showPhotoSourceSheet,
                  child: Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 24),
                        Gap(4),
                        Text('Add Photo', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // STEP 5: OPERATIONS & HUB
  Widget _buildStep5Operations() {
    final hubsAsync = ref.watch(vendorPickupHubsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operations & Yard Assignment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Gap(4),
        const Text(
          'Assign vehicle to your operating yard/pickup hub in a platform-supported city.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const Gap(20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Operating Yard / Pickup Hub *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: _showAddHubDialog,
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text('Add Yard', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const Gap(6),

        hubsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                const Gap(8),
                Expanded(
                  child: Text('Failed to load hubs: $err', style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                ),
              ],
            ),
          ),
          data: (hubs) {
            if (hubs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const Gap(8),
                    const Text(
                      'No Operating Yards Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const Gap(4),
                    const Text(
                      'Every vehicle must be stationed at a genuine registered yard. Please add your operating yard below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const Gap(12),
                    ElevatedButton.icon(
                      onPressed: _showAddHubDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Register First Operating Yard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              );
            }

            final currentSelection = hubs.any((h) => (h['id'] ?? '') == _selectedHubId)
                ? _selectedHubId
                : hubs.first['id']?.toString();

            if (_selectedHubId != currentSelection || _selectedHubName == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedHubId = currentSelection;
                    final match = hubs.firstWhere((h) => (h['id'] ?? '') == currentSelection, orElse: () => {});
                    _selectedHubName = match['name']?.toString() ?? 'Yard';
                  });
                }
              });
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedHubId,
                  isExpanded: true,
                  hint: const Text('Select Operating Yard'),
                  items: hubs.map((h) {
                    final hubId = h['id']?.toString() ?? '';
                    final hubName = h['name']?.toString() ?? 'Operating Yard';
                    final city = h['city']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: hubId,
                      child: Text('$hubName ($city)', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedHubId = val;
                      final match = hubs.firstWhere((h) => (h['id'] ?? '') == val, orElse: () => {});
                      _selectedHubName = match['name']?.toString() ?? 'Yard';
                    });
                  },
                ),
              ),
            );
          },
        ),
        const Gap(20),

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
                  Text('Make Available Immediately', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Gap(2),
                  Text('Car will accept customer bookings once verified by admin', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
              Switch(
                value: _isAvailableOnPublish,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => _isAvailableOnPublish = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 6: REVIEW & PUBLISH
  Widget _buildStep6Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Vehicle Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Gap(4),
        const Text(
          'Please verify all information before publishing the vehicle to your live fleet.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        const Gap(16),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo + Title
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF1F5F9),
                    ),
                    child: _photos.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(_photos.first, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.directions_car),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_makeCtrl.text.trim()} ${_modelCtrl.text.trim()} ${_variantCtrl.text.trim()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Gap(2),
                        Text(
                          'Plate: ${_regNumCtrl.text.trim().toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              _buildReviewRow('Manufacturing Year', '$_selectedYear'),
              _buildReviewRow('Category / Fuel', '$_selectedCategory • $_selectedFuelType'),
              _buildReviewRow('Transmission / Seats', '$_selectedTransmission • ${_seatingCtrl.text.trim()} Seats'),
              _buildReviewRow('Air Conditioning', _isAC ? 'Yes (AC)' : 'No (Non-AC)'),
              _buildReviewRow('Daily Rental Rate', '₹${_priceDayCtrl.text.trim()}/day'),
              _buildReviewRow('Hourly Rate', '₹${_priceHourCtrl.text.trim()}/hr'),
              _buildReviewRow('Pickup Yard', _selectedHubName ?? _selectedHubId ?? 'Assigned Yard'),
              _buildReviewRow('Initial Status', _isAvailableOnPublish ? 'Available (Active)' : 'Draft (Offline)'),
              _buildReviewRow('Authentic Photos', '${_photos.length} uploaded'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const Gap(6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
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

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
