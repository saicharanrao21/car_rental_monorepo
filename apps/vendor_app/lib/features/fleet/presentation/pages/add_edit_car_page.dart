import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import '../providers/fleet_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class AddEditCarPage extends ConsumerStatefulWidget {
  final String? carId;

  const AddEditCarPage({super.key, this.carId});

  @override
  ConsumerState<AddEditCarPage> createState() => _AddEditCarPageState();
}

class _AddEditCarPageState extends ConsumerState<AddEditCarPage> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.carId != null;

  // Controllers
  late TextEditingController _makeCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _regNumCtrl;
  late TextEditingController _seatingCtrl;
  late TextEditingController _priceKmCtrl;
  late TextEditingController _priceDayCtrl;
  late TextEditingController _priceHourCtrl;

  // Dropdowns and toggles state
  int? _selectedYear;
  String? _selectedCategory;
  String? _selectedFuelType;
  bool _isAC = true;
  List<String> _selectedTripTypes = [];
  List<String> _photos = [];
  String? _rcBookPath;
  String? _insurancePath;
  DateTime? _rcBookExpiry;
  DateTime? _insuranceExpiry;

  // Year list: last 15 years
  late List<int> _years;

  @override
  void initState() {
    super.initState();

    final currentYear = DateTime.now().year;
    _years = List.generate(15, (index) => currentYear - index);

    // Initialize blank values
    _makeCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _regNumCtrl = TextEditingController();
    _seatingCtrl = TextEditingController();
    _priceKmCtrl = TextEditingController();
    _priceDayCtrl = TextEditingController();
    _priceHourCtrl = TextEditingController();

    // If edit mode, populate data
    if (isEditMode) {
      // Find the car in live fleet provider
      final carsList = ref.read(fleetCarsProvider).value ?? [];
      final car = carsList.firstWhere(
        (c) => c.id == widget.carId,
        orElse: () => const CarModel(
          id: '',
          vendorId: '',
          make: '',
          model: '',
          year: 2022,
          type: 'Sedan',
          fuelType: 'Petrol',
          seating: 5,
          isAC: true,
          photos: [],
          pricePerKm: 0,
          pricePerDay: 0,
          pricePerHour: 0,
        ),
      );

      if (car.id.isNotEmpty) {
        _makeCtrl.text = car.make;
        _modelCtrl.text = car.model;
        // Since registration number wasn't in CarModel, let's prefill with a simulated reg number or blank
        _regNumCtrl.text = 'MH 12 AB ${1000 + car.id.hashCode % 9000}';
        _seatingCtrl.text = car.seating.toString();
        _priceKmCtrl.text = car.pricePerKm.toStringAsFixed(0);
        _priceDayCtrl.text = car.pricePerDay.toStringAsFixed(0);
        _priceHourCtrl.text = car.pricePerHour.toStringAsFixed(0);

        _selectedYear = car.year;
        _selectedCategory = car.type;
        _selectedFuelType = car.fuelType;
        _isAC = car.isAC;
        _selectedTripTypes = List.from(car.availableTripTypes);
        _photos = List.from(car.photos);
      }
    } else {
      // Defaults for add car
      _selectedYear = currentYear;
      _selectedCategory = AppConstants.carCategories.first;
      _selectedFuelType = 'Petrol';
      _selectedTripTypes = List.from(AppConstants.tripTypes);
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _regNumCtrl.dispose();
    _seatingCtrl.dispose();
    _priceKmCtrl.dispose();
    _priceDayCtrl.dispose();
    _priceHourCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulatePhotoSelection(int index) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            Gap(20),
            Text('Accessing Gallery & Uploading…'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading

    setState(() {
      final fakeUrl = 'https://images.unsplash.com/photo-${1549399542 + index}-fake';
      if (index < _photos.length) {
        _photos[index] = fakeUrl;
      } else {
        _photos.add(fakeUrl);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo ${index + 1} uploaded successfully (Simulated)')),
    );
  }

  Future<void> _simulateCarDocUpload(String docType) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Select $docType Expiry Date',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            Gap(20),
            Text('Selecting & processing document…'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    Navigator.of(context).pop();

    setState(() {
      if (docType == 'RC Book') {
        _rcBookPath = 'rc_book_${DateTime.now().millisecondsSinceEpoch}.pdf';
        _rcBookExpiry = pickedDate;
      } else if (docType == 'Insurance') {
        _insurancePath = 'insurance_${DateTime.now().millisecondsSinceEpoch}.pdf';
        _insuranceExpiry = pickedDate;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$docType attached with expiry date')),
    );
  }

  Widget _buildCarDocUploadCard(String label, String? filePath, DateTime? expiry, VoidCallback onTap) {
    final hasFile = filePath != null;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasFile ? Colors.green.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFile ? Icons.check_circle : Icons.description_outlined,
                color: hasFile ? Colors.green : AppColors.primary,
                size: 24,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Gap(4),
                  Text(
                    hasFile
                        ? (expiry != null ? 'File attached • Expiry: ${expiry.day}/${expiry.month}/${expiry.year}' : 'File attached')
                        : 'PDF or JPG up to 5MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: hasFile ? Colors.green : AppColors.primary,
                side: BorderSide(color: hasFile ? Colors.green : AppColors.primary),
              ),
              child: Text(hasFile ? 'Change' : 'Choose'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = ref.read(vendorSessionProvider);
    final vendorId = session.vendor?.id;
    if (vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No vendor session found')),
      );
      return;
    }

    // Prepare car model
    final car = CarModel(
      id: isEditMode ? widget.carId! : 'car_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: vendorId,
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: _selectedYear ?? DateTime.now().year,
      type: _selectedCategory ?? 'Sedan',
      fuelType: _selectedFuelType ?? 'Petrol',
      seating: int.tryParse(_seatingCtrl.text.trim()) ?? 5,
      isAC: _isAC,
      photos: _photos.isNotEmpty ? _photos : ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: double.tryParse(_priceKmCtrl.text.trim()) ?? 0.0,
      pricePerDay: double.tryParse(_priceDayCtrl.text.trim()) ?? 0.0,
      pricePerHour: double.tryParse(_priceHourCtrl.text.trim()) ?? 0.0,
      registrationNumber: _regNumCtrl.text.trim(),
      isAvailable: isEditMode
          ? (ref.read(fleetCarsProvider).value?.firstWhere((c) => c.id == widget.carId, orElse: () => const CarModel(id: '', vendorId: '', make: '', model: '', year: 2022, type: '', fuelType: '', seating: 5, isAC: true, photos: [], pricePerKm: 0, pricePerDay: 0, pricePerHour: 0)).isAvailable)
          : true,
      rating: isEditMode
          ? (ref.read(fleetCarsProvider).value?.firstWhere((c) => c.id == widget.carId, orElse: () => const CarModel(id: '', vendorId: '', make: '', model: '', year: 2022, type: '', fuelType: '', seating: 5, isAC: true, photos: [], pricePerKm: 0, pricePerDay: 0, pricePerHour: 0)).rating)
          : 5.0,
      availableTripTypes: _selectedTripTypes,
    );

    bool success = false;
    if (isEditMode) {
      success = await ref.read(fleetControllerProvider.notifier).updateCar(car);
    } else {
      success = await ref.read(fleetControllerProvider.notifier).addCar(car);
    }

    if (success) {
      // Upload car-specific documents (RC Book / Insurance) with carId if selected
      final repo = ref.read(fleetRepositoryProvider);
      if (_rcBookPath != null) {
        try {
          await repo.uploadCarDocument(carId: car.id, type: 'RC_BOOK', fileUrl: _rcBookPath!, expiresAt: _rcBookExpiry);
        } catch (_) {}
      }
      if (_insurancePath != null) {
        try {
          await repo.uploadCarDocument(carId: car.id, type: 'INSURANCE', fileUrl: _insurancePath!, expiresAt: _insuranceExpiry);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode ? 'Car updated successfully' : 'Car added successfully')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fleetControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Car' : 'Add New Car'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photos section
              const SectionHeader(title: 'Car Photos (Max 6)'),
              const Gap(12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final hasPhoto = index < _photos.length;
                  return GestureDetector(
                    onTap: () => _simulatePhotoSelection(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: hasPhoto
                          ? Stack(
                              children: [
                                const Center(
                                  child: Icon(Icons.directions_car, size: 40, color: Colors.green),
                                ),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _photos.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: AppColors.primary, size: 24),
                                Gap(4),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
              const Gap(24),

              // Basic vehicle info
              const SectionHeader(title: 'Vehicle Details'),
              const Gap(12),
              AppTextField(
                label: 'Make',
                hint: 'e.g. Maruti Suzuki, Hyundai',
                controller: _makeCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Make is required' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'Model',
                hint: 'e.g. Swift, Creta',
                controller: _modelCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Model is required' : null,
              ),
              const Gap(16),

              // Row for Year & Category Dropdowns
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<int>(
                      label: 'Year',
                      value: _selectedYear,
                      items: _years.map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text(y.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedYear = val;
                        });
                      },
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'Category',
                      value: _selectedCategory,
                      items: AppConstants.carCategories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'Fuel Type',
                      value: _selectedFuelType,
                      items: ['Petrol', 'Diesel', 'CNG', 'Electric'].map((fuel) {
                        return DropdownMenuItem<String>(
                          value: fuel,
                          child: Text(fuel),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFuelType = val;
                        });
                      },
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: AppTextField(
                      label: 'Seating Capacity',
                      hint: 'e.g. 5',
                      controller: _seatingCtrl,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Must be number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const Gap(16),

              AppTextField(
                label: 'Registration Number',
                hint: 'e.g. MH 12 AB 1234',
                controller: _regNumCtrl,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Registration number is required' : null,
              ),
              const Gap(16),

              // AC/Non-AC Toggle Cards
              const Text(
                'Air Conditioning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAC = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isAC ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(
                            color: _isAC ? AppColors.primary : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'AC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isAC ? AppColors.primary : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAC = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isAC ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                          border: Border.all(
                            color: !_isAC ? AppColors.primary : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Non-AC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isAC ? AppColors.primary : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // Pricing section
              const SectionHeader(title: 'Pricing Rates (INR)'),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Per KM Rate',
                      hint: '15',
                      controller: _priceKmCtrl,
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Per Day Rate',
                      hint: '2500',
                      controller: _priceDayCtrl,
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Per Hour Rate',
                      hint: '200',
                      controller: _priceHourCtrl,
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // Available Trip Types Chip selection
              const SectionHeader(title: 'Available Trip Types'),
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.tripTypes.map((type) {
                  final isSelected = _selectedTripTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTripTypes.add(type);
                        } else {
                          _selectedTripTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const Gap(32),

              // Car Documents (RC Book & Insurance)
              const SectionHeader(title: 'Car Documents'),
              const Gap(8),
              Text(
                'Upload car-specific legal & registration documents.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Gap(12),
              _buildCarDocUploadCard('RC Book', _rcBookPath, _rcBookExpiry, () => _simulateCarDocUpload('RC Book')),
              const Gap(12),
              _buildCarDocUploadCard('Insurance Policy', _insurancePath, _insuranceExpiry, () => _simulateCarDocUpload('Insurance')),
              const Gap(32),

              // Save button
              AppButton(
                text: isEditMode ? 'Update Car' : 'Add Car to Fleet',
                onPressed: _saveCar,
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}
