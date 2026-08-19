import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('MileagePackageModel Tests', () => {
    test('MileagePackageModel.fromJson parses standard package payload correctly', () {
      final json = {
        'id': 'pkg_123',
        'carId': 'car_456',
        'tripType': 'SELF_DRIVE',
        'name': '100 km/day',
        'includedKmPerDay': 100,
        'basePricePerDay': 2500,
        'extraKmRate': 12,
        'isDefault': true,
        'isActive': true,
        'createdAt': '2026-08-19T10:00:00.000Z',
        'updatedAt': '2026-08-19T10:00:00.000Z',
      };

      final model = MileagePackageModel.fromJson(json);

      expect(model.id, 'pkg_123');
      expect(model.carId, 'car_456');
      expect(model.tripType, 'Self-Drive');
      expect(model.name, '100 km/day');
      expect(model.includedKmPerDay, 100);
      expect(model.isUnlimited, false);
      expect(model.basePricePerDay, 2500.0);
      expect(model.extraKmRate, 12.0);
      expect(model.isDefault, true);
      expect(model.isActive, true);
      expect(model.totalIncludedKm(3), 300);
    }),

    test('MileagePackageModel handles Unlimited package correctly', () {
      final json = {
        'id': 'pkg_unlimited',
        'carId': 'car_456',
        'tripType': 'OUTSTATION',
        'name': 'Unlimited',
        'includedKmPerDay': null,
        'basePricePerDay': 4500,
        'extraKmRate': 0,
        'isDefault': false,
        'isActive': true,
      };

      final model = MileagePackageModel.fromJson(json);

      expect(model.id, 'pkg_unlimited');
      expect(model.tripType, 'Outstation');
      expect(model.includedKmPerDay, isNull);
      expect(model.isUnlimited, true);
      expect(model.totalIncludedKm(5), isNull);
    }),

    test('MileagePackageModel.toJson produces valid backend format', () {
      const model = MileagePackageModel(
        id: 'pkg_test',
        carId: 'car_test',
        tripType: 'Self-Drive',
        name: '200 km/day',
        includedKmPerDay: 200,
        basePricePerDay: 3200,
        extraKmRate: 10,
        isDefault: true,
        isActive: true,
      );

      final json = model.toJson();

      expect(json['tripType'], 'SELF_DRIVE');
      expect(json['includedKmPerDay'], 200);
      expect(json['basePricePerDay'], 3200.0);
      expect(json['extraKmRate'], 10.0);
      expect(json['isDefault'], true);
    }),

    test('CarModel parses embedded mileagePackages payload safely', () {
      final carJson = {
        'id': 'car_123',
        'vendorId': 'vendor_123',
        'make': 'Mahindra',
        'model': 'Thar',
        'year': 2023,
        'type': 'SUV',
        'fuelType': 'Diesel',
        'seating': 4,
        'isAC': true,
        'photos': [],
        'pricePerKm': 18.0,
        'pricePerDay': 3500.0,
        'pricePerHour': 250.0,
        'mileagePackages': [
          {
            'id': 'pkg_1',
            'carId': 'car_123',
            'tripType': 'SELF_DRIVE',
            'name': '100 km/day',
            'includedKmPerDay': 100,
            'basePricePerDay': 3000,
            'extraKmRate': 15,
            'isDefault': true,
          }
        ],
      };

      final car = CarModel.fromJson(carJson);
      expect(car.rawMileagePackages.length, 1);
      final package = MileagePackageModel.fromJson(
        Map<String, dynamic>.from(car.rawMileagePackages.first as Map),
      );
      expect(package.name, '100 km/day');
      expect(package.tripType, 'Self-Drive');
      expect(package.includedKmPerDay, 100);
    }),
  });
}
