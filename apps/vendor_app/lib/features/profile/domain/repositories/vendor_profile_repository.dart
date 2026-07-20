import 'package:models/models.dart';

abstract interface class VendorProfileRepository {
  Future<void> updateBusinessProfile(VendorModel vendor);
}
