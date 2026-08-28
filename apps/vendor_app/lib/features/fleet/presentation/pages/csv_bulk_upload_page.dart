import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../providers/fleet_providers.dart';
import '../../../../core/providers/vendor_session_provider.dart';

class CsvRowItem {
  final int rowNumber;
  final Map<String, String> rawData;
  final List<String> errors;
  final CarModel? parsedCar;

  CsvRowItem({
    required this.rowNumber,
    required this.rawData,
    required this.errors,
    this.parsedCar,
  });

  bool get isValid => errors.isEmpty && parsedCar != null;
}

class CsvBulkUploadPage extends ConsumerStatefulWidget {
  const CsvBulkUploadPage({super.key});

  @override
  ConsumerState<CsvBulkUploadPage> createState() => _CsvBulkUploadPageState();
}

class _CsvBulkUploadPageState extends ConsumerState<CsvBulkUploadPage> {
  String? _fileName;
  List<CsvRowItem> _rows = [];
  bool _isParsing = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _successCount = 0;
  int _failCount = 0;

  static const String sampleCsvTemplate = '''make,model,year,type,fuelType,seating,isAC,registrationNumber,pricePerKm,pricePerDay,pricePerHour,availableTripTypes
Maruti Suzuki,Swift,2022,HATCHBACK,PETROL,5,true,MH 12 AB 1234,12,2000,150,LOCAL;OUTSTATION
Hyundai,Creta,2023,SUV,DIESEL,5,true,MH 12 CD 5678,16,3200,250,LOCAL;OUTSTATION;HOURLY
Tata,Nexon EV,2024,SUV,ELECTRIC,5,true,MH 12 EV 9999,15,3500,280,LOCAL;HOURLY
Toyota,Innova,2021,VAN,Diesel,7,true,MH 12 XY 4321,20,4500,350,LOCAL;OUTSTATION''';

  void _showTemplateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CSV Template Format', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Gap(10),
            const Text(
              'Expected Header Columns:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Gap(4),
            Text(
              'make, model, year, type, fuelType, seating, isAC, registrationNumber, pricePerKm, pricePerDay, pricePerHour, availableTripTypes',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const Gap(12),
            const Text('Allowed Values:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(4),
            Text('• type: SEDAN, SUV, HATCHBACK, LUXURY, VAN, CONVERTIBLE\n• fuelType: PETROL, DIESEL, CNG, ELECTRIC, HYBRID\n• availableTripTypes: LOCAL;OUTSTATION;HOURLY (semicolon-separated)', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const Gap(16),
            const Text('Sample Template:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const SelectableText(
                sampleCsvTemplate,
                style: TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndParseCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file content')),
        );
        return;
      }

      setState(() {
        _isParsing = true;
        _fileName = file.name;
        _rows = [];
      });

      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.isEmpty) {
        setState(() => _isParsing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty')),
        );
        return;
      }

      final header = csvTable.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final parsedRows = <CsvRowItem>[];

      final vendorId = ref.read(vendorSessionProvider).vendor?.id ?? '';

      for (int i = 1; i < csvTable.length; i++) {
        final rowData = csvTable[i];
        if (rowData.isEmpty || (rowData.length == 1 && rowData[0].toString().trim().isEmpty)) {
          continue; // Skip empty trailing lines
        }

        final map = <String, String>{};
        for (int h = 0; h < header.length; h++) {
          if (h < rowData.length) {
            map[header[h]] = rowData[h].toString().trim();
          }
        }

        final errors = <String>[];

        final make = map['make'] ?? '';
        final model = map['model'] ?? '';
        final yearStr = map['year'] ?? '';
        final typeStr = (map['type'] ?? '').toUpperCase();
        final fuelStr = (map['fueltype'] ?? map['fuel_type'] ?? '').toUpperCase();
        final seatingStr = map['seating'] ?? '';
        final isAcStr = (map['isac'] ?? map['is_ac'] ?? 'true').toLowerCase();
        final regNum = map['registrationnumber'] ?? map['registration_number'] ?? '';
        final priceKmStr = map['priceperkm'] ?? map['price_per_km'] ?? '';
        final priceDayStr = map['priceperday'] ?? map['price_per_day'] ?? '';
        final priceHourStr = map['priceperhour'] ?? map['price_per_hour'] ?? '';
        final tripTypesRaw = map['availabletriptypes'] ?? map['available_trip_types'] ?? 'LOCAL;OUTSTATION';

        if (make.isEmpty) errors.add('Missing make');
        if (model.isEmpty) errors.add('Missing model');

        final year = int.tryParse(yearStr);
        if (year == null || year < 2000 || year > DateTime.now().year + 1) {
          errors.add('Invalid year "$yearStr"');
        }

        const validTypes = ['SEDAN', 'SUV', 'HATCHBACK', 'LUXURY', 'VAN', 'CONVERTIBLE', 'COUPE', 'CROSSOVER', 'MUV'];
        if (!validTypes.contains(typeStr)) {
          errors.add('Invalid type "$typeStr", expected one of $validTypes');
        }

        const validFuels = ['PETROL', 'DIESEL', 'CNG', 'ELECTRIC', 'HYBRID'];
        if (!validFuels.contains(fuelStr)) {
          errors.add('Invalid fuelType "$fuelStr", expected one of $validFuels');
        }

        final seating = int.tryParse(seatingStr);
        if (seating == null || seating <= 0) {
          errors.add('Invalid seating "$seatingStr"');
        }

        final isAC = isAcStr == 'true' || isAcStr == '1' || isAcStr == 'yes';

        if (regNum.isEmpty) errors.add('Missing registration number');

        final priceKm = double.tryParse(priceKmStr);
        if (priceKm == null || priceKm < 0) errors.add('Invalid pricePerKm "$priceKmStr"');

        final priceDay = double.tryParse(priceDayStr);
        if (priceDay == null || priceDay <= 0) errors.add('Invalid pricePerDay "$priceDayStr"');

        final priceHour = double.tryParse(priceHourStr);
        if (priceHour == null || priceHour < 0) errors.add('Invalid pricePerHour "$priceHourStr"');

        final tripTypes = tripTypesRaw
            .split(';')
            .map((t) => t.trim().toUpperCase())
            .where((t) => t.isNotEmpty)
            .toList();

        CarModel? car;
        if (errors.isEmpty) {
          car = CarModel(
            id: '',
            vendorId: vendorId,
            make: make,
            model: model,
            year: year!,
            type: typeStr,
            fuelType: fuelStr,
            seating: seating!,
            isAC: isAC,
            photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
            pricePerKm: priceKm!,
            pricePerDay: priceDay!,
            pricePerHour: priceHour!,
            registrationNumber: regNum,
            availableTripTypes: tripTypes.isNotEmpty ? tripTypes : ['LOCAL', 'OUTSTATION'],
            isAvailable: true,
          );
        }

        parsedRows.add(CsvRowItem(
          rowNumber: i + 1,
          rawData: map,
          errors: errors,
          parsedCar: car,
        ));
      }

      setState(() {
        _isParsing = false;
        _rows = parsedRows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing CSV: $e')),
      );
    }
  }

  Future<void> _submitValidCars() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid cars to upload')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _successCount = 0;
      _failCount = 0;
    });

    final repo = ref.read(fleetRepositoryProvider);

    for (int i = 0; i < validRows.length; i++) {
      final row = validRows[i];
      try {
        await repo.addCar(row.parsedCar!);
        _successCount++;
      } catch (e) {
        _failCount++;
      }

      setState(() {
        _uploadProgress = i + 1;
      });
    }

    ref.invalidate(fleetCarsProvider);

    setState(() {
      _isUploading = false;
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Bulk Upload Completed'),
          content: Text(
            '$_successCount of ${validRows.length} valid cars added successfully.'
            '${_failCount > 0 ? '\n$_failCount cars failed to save.' : ''}',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((r) => r.isValid).length;
    final invalidCount = _rows.where((r) => !r.isValid).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Car Upload (CSV)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'View Format Template',
            onPressed: _showTemplateModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top guidance card
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.upload_file, color: AppColors.primary, size: 28),
                        Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Upload Fleet CSV File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Gap(2),
                              Text('Add multiple cars to your fleet instantly via CSV.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showTemplateModal,
                            icon: const Icon(Icons.table_chart_outlined, size: 18),
                            label: const Text('View Template'),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploading || _isParsing ? null : _pickAndParseCsv,
                            icon: _isParsing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.folder_open, size: 18),
                            label: Text(_fileName == null ? 'Select CSV' : 'Change File'),
                          ),
                        ),
                      ],
                    ),
                    if (_fileName != null) ...[
                      const Gap(10),
                      Text('Selected file: $_fileName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                    ],
                  ],
                ),
              ),
            ),
            const Gap(20),

            if (_rows.isNotEmpty) ...[
              // Summary row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[300]!)),
                      child: Column(
                        children: [
                          Text('$validCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800])),
                          const Text('Valid Rows', style: TextStyle(fontSize: 12, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: invalidCount > 0 ? Colors.red[50] : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: invalidCount > 0 ? Colors.red[300]! : Colors.grey[300]!)),
                      child: Column(
                        children: [
                          Text('$invalidCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: invalidCount > 0 ? Colors.red[800] : Colors.grey[700])),
                          Text('Invalid Rows', style: TextStyle(fontSize: 12, color: invalidCount > 0 ? Colors.red[800] : Colors.grey[700])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(20),

              const SectionHeader(title: 'Parsed Preview & Validation'),
              const Gap(10),

              // Preview Data Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Make & Model', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Fuel', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Reg No', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Rate/Day', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Validation Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _rows.map((r) {
                    final isOk = r.isValid;
                    return DataRow(
                      color: WidgetStateProperty.all(isOk ? Colors.white : Colors.red[50]),
                      cells: [
                        DataCell(Text('${r.rowNumber}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOk ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOk ? 'VALID' : 'ERROR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOk ? Colors.green[900] : Colors.red[900],
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('${r.rawData['make'] ?? ''} ${r.rawData['model'] ?? ''}')),
                        DataCell(Text(r.rawData['year'] ?? '')),
                        DataCell(Text(r.rawData['type'] ?? '')),
                        DataCell(Text(r.rawData['fueltype'] ?? r.rawData['fuel_type'] ?? '')),
                        DataCell(Text(r.rawData['registrationnumber'] ?? r.rawData['registration_number'] ?? '')),
                        DataCell(Text('₹${r.rawData['priceperday'] ?? r.rawData['price_per_day'] ?? ''}')),
                        DataCell(
                          Text(
                            isOk ? 'Ready to import' : r.errors.join('; '),
                            style: TextStyle(
                              fontSize: 11,
                              color: isOk ? Colors.green[800] : Colors.red[800],
                              fontWeight: isOk ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const Gap(24),

              if (_isUploading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(value: validCount > 0 ? _uploadProgress / validCount : 0),
                    const Gap(8),
                    Text('Uploading $_uploadProgress of $validCount valid cars…', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Gap(20),
              ],

              AppButton(
                text: 'Confirm & Upload $validCount Cars',
                onPressed: _isUploading || validCount == 0 ? null : _submitValidCars,
                isLoading: _isUploading,
              ),
              const Gap(30),
            ],
          ],
        ),
      ),
    );
  }
}
