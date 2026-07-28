import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/branches_provider.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class AddBranchPage extends ConsumerStatefulWidget {
  const AddBranchPage({super.key});

  @override
  ConsumerState<AddBranchPage> createState() => _AddBranchPageState();
}

class _AddBranchPageState extends ConsumerState<AddBranchPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLocating = false;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _localityCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;
  String? _selectedCity = 'Mumbai';

  static const _cities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    'Pune', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Surat',
  ];

  @override
  void initState() {
    super.initState();
    final parent = ref.read(vendorSessionProvider).vendor;
    _businessNameCtrl = TextEditingController(text: parent != null ? '${parent.businessName} - Branch' : '');
    _ownerNameCtrl = TextEditingController(text: parent?.ownerName ?? '');
    _localityCtrl = TextEditingController();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();
    _gstCtrl = TextEditingController(text: parent?.gstNumber ?? '');
    _panCtrl = TextEditingController(text: parent?.panNumber ?? '');
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _localityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled on your device.')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch GPS location captured successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitBranch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post('/vendors/me/branches', data: {
        'businessName': _businessNameCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'city': _selectedCity,
        'locality': _localityCtrl.text.trim().isEmpty ? null : _localityCtrl.text.trim(),
        'latitude': double.tryParse(_latCtrl.text.trim()),
        'longitude': double.tryParse(_lngCtrl.text.trim()),
        'gstNumber': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        'panNumber': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      });

      ref.invalidate(vendorBranchesProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add branch: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Branch'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Branch Details'),
              const Gap(12),
              AppTextField(
                label: 'Branch Business Name',
                hint: 'e.g. DriveGo Fleet - Thane Branch',
                controller: _businessNameCtrl,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const Gap(16),
              AppTextField(
                label: 'Branch Manager / Owner Name',
                controller: _ownerNameCtrl,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const Gap(16),

              AppDropdown<String>(
                label: 'City',
                value: _selectedCity,
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
              ),
              const Gap(16),

              AppTextField(
                label: 'Locality / Area',
                hint: 'e.g. Thane West, Whitefield',
                controller: _localityCtrl,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Locality is required' : null,
              ),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Latitude',
                      hint: '19.2183',
                      controller: _latCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: AppTextField(
                      label: 'Longitude',
                      hint: '72.9781',
                      controller: _lngCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              OutlinedButton.icon(
                onPressed: _isLocating ? null : _getCurrentLocation,
                icon: _isLocating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Use branch current GPS location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const Gap(24),

              const SectionHeader(title: 'Tax & Registration (Optional)'),
              const Gap(12),
              AppTextField(
                label: 'GST Number',
                controller: _gstCtrl,
              ),
              const Gap(16),
              AppTextField(
                label: 'PAN Number',
                controller: _panCtrl,
              ),
              const Gap(30),

              AppButton(
                text: 'Create Branch Profile',
                onPressed: _isLoading ? null : _submitBranch,
                isLoading: _isLoading,
              ),
              const Gap(30),
            ],
          ),
        ),
      ),
    );
  }
}
