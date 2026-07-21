import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_profile_repository.dart';

class MockVendorProfileRepository with LatencySimulator implements VendorProfileRepository {
  @override
  Future<VendorModel> updateBusinessProfile(VendorModel vendor) async {
    await simulateLatency();
    final index = MockData.vendors.indexWhere((v) => v.id == vendor.id);
    if (index != -1) {
      MockData.vendors[index] = vendor;
    }
    return vendor;
  }
}
