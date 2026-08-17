import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('ProtectionPackageModel Tests', () {
    test('ProtectionPackageModel.fromJson parses package correctly', () {
      final json = {
        'id': 'prot_1',
        'code': 'ZERO_DEP',
        'name': 'Premium Zero-Depreciation',
        'description': '100% bumper to bumper protection',
        'dailyRate': 500.0,
        'deductibleAmount': 0.0,
        'maxCoverageAmount': 500000.0,
        'coverageSummary': ['Zero Deductible', 'Accidental Damage', 'Theft Protection', 'Towing'],
        'exclusions': ['Drunk Driving', 'Off-road Driving'],
        'isActive': true,
      };

      final pkg = ProtectionPackageModel.fromJson(json);

      expect(pkg.id, 'prot_1');
      expect(pkg.code, ProtectionPlanCode.ZERO_DEP);
      expect(pkg.dailyRate, 500.0);
      expect(pkg.deductibleAmount, 0.0);
      expect(pkg.maxCoverageAmount, 500000.0);
      expect(pkg.coverageSummary.length, 4);
      expect(pkg.coverageSummary, contains('Zero Deductible'));
      expect(pkg.exclusions, contains('Drunk Driving'));
      expect(pkg.isActive, isTrue);
    });
  });
}
