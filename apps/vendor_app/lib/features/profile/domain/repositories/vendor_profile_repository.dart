import 'package:models/models.dart';

abstract interface class VendorProfileRepository {
  Future<VendorModel> updateBusinessProfile(VendorModel vendor);
}
