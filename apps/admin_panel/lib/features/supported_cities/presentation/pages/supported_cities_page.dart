import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:gap/gap.dart';
import '../providers/supported_cities_providers.dart';

class SupportedCitiesPage extends ConsumerWidget {
  const SupportedCitiesPage({super.key});

  void _showCityForm(BuildContext context, WidgetRef ref, [SupportedCityModel? city]) {
    AppBottomSheet.show(
      context,
      title: city == null ? 'Add Supported City' : 'Edit Supported City',
      child: _CityFormModal(
        cityToEdit: city,
        onSave: ({
          required String name,
          required String stateName,
          required double latitude,
          required double longitude,
          required bool isActive,
        }) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            if (city == null) {
              await ref.read(supportedCitiesProvider.notifier).addCity(
                    name: name,
                    stateName: stateName,
                    latitude: latitude,
                    longitude: longitude,
                    isActive: isActive,
                  );
              messenger.showSnackBar(
                const SnackBar(content: Text('City added successfully!'), backgroundColor: Colors.green),
              );
            } else {
              await ref.read(supportedCitiesProvider.notifier).updateCity(
                    city.id,
                    name: name,
                    stateName: stateName,
                    latitude: latitude,
                    longitude: longitude,
                    isActive: isActive,
                  );
              messenger.showSnackBar(
                const SnackBar(content: Text('City updated successfully!'), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Failed to save city: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  void _confirmDeleteCity(BuildContext context, WidgetRef ref, SupportedCityModel city) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Supported City'),
          content: Text('Are you sure you want to delete "${city.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(supportedCitiesProvider.notifier).deleteCity(city.id);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('City deleted successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete city: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(supportedCitiesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported Cities',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Gap(4),
                    Text(
                      'Manage operational cities, geographic coordinates, and active service areas across India.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Add Supported City',
                  isFullWidth: false,
                  onPressed: () => _showCityForm(context, ref),
                ),
              ],
            ),
            const Gap(24),
            Expanded(
              child: citiesAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading supported cities',
                  onRetry: () => ref.invalidate(supportedCitiesProvider),
                ),
                data: (cities) {
                  if (cities.isEmpty) {
                    return AppCard(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_city_outlined, size: 48, color: Colors.grey),
                            const Gap(12),
                            const Text('No supported cities found', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Gap(4),
                            const Text('Click "Add Supported City" above to add your first operational city.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const Gap(16),
                            AppButton(
                              text: 'Add City',
                              isFullWidth: false,
                              onPressed: () => _showCityForm(context, ref),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AppCard(
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('City Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Coordinates (Lat, Lng)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: cities.map((city) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  city.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(Text(city.state)),
                              DataCell(
                                Text(
                                  '${city.latitude.toStringAsFixed(4)}, ${city.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              DataCell(
                                StatusBadge(
                                  status: city.isActive ? 'Active' : 'Inactive',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit City',
                                      onPressed: () => _showCityForm(context, ref, city),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      tooltip: 'Delete City',
                                      onPressed: () => _confirmDeleteCity(context, ref, city),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityFormModal extends StatefulWidget {
  final SupportedCityModel? cityToEdit;
  final Function({
    required String name,
    required String stateName,
    required double latitude,
    required double longitude,
    required bool isActive,
  }) onSave;

  const _CityFormModal({
    this.cityToEdit,
    required this.onSave,
  });

  @override
  State<_CityFormModal> createState() => _CityFormModalState();
}

class _CityFormModalState extends State<_CityFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _stateController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cityToEdit?.name ?? '');
    _stateController = TextEditingController(text: widget.cityToEdit?.state ?? '');
    _latController = TextEditingController(
      text: widget.cityToEdit != null ? widget.cityToEdit!.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: widget.cityToEdit != null ? widget.cityToEdit!.longitude.toString() : '',
    );
    _isActive = widget.cityToEdit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stateController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();
    final stateName = _stateController.text.trim();
    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());

    await widget.onSave(
      name: name,
      stateName: stateName,
      latitude: lat,
      longitude: lng,
      isActive: _isActive,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'City Name',
              controller: _nameController,
              hint: 'e.g. Pune',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'City name is required';
                return null;
              },
            ),
            const Gap(16),
            AppTextField(
              label: 'State',
              controller: _stateController,
              hint: 'e.g. Maharashtra',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'State is required';
                return null;
              },
            ),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Latitude',
                    controller: _latController,
                    hint: 'e.g. 18.5204',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Latitude is required';
                      if (double.tryParse(val.trim()) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: AppTextField(
                    label: 'Longitude',
                    controller: _lngController,
                    hint: 'e.g. 73.8567',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Longitude is required';
                      if (double.tryParse(val.trim()) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const Gap(16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active Status', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Active cities are available for customer bookings and search selection.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              value: _isActive,
              onChanged: (val) {
                setState(() {
                  _isActive = val;
                });
              },
            ),
            const Gap(24),
            _isSaving
                ? const Center(child: AppLoader())
                : AppButton(
                    text: widget.cityToEdit == null ? 'Add City' : 'Save Changes',
                    onPressed: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}
