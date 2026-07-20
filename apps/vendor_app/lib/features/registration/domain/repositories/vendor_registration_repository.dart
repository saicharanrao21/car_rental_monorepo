import 'package:models/models.dart';
import '../../presentation/providers/registration_providers.dart';

abstract class VendorRegistrationRepository {
  Future<VendorModel> registerVendor(VendorRegistrationDraft draft);
}
