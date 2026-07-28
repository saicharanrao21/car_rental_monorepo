import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/vendor_profile_repository.dart';

class ApiVendorProfileRepository implements VendorProfileRepository {
  final ApiClient apiClient;

  ApiVendorProfileRepository({required this.apiClient});

  @override
  Future<VendorModel> updateBusinessProfile(VendorModel vendor) async {
    final response = await apiClient.dio.patch(
      '/vendors/me',
      data: {
        if (vendor.businessName.isNotEmpty) 'businessName': vendor.businessName,
        if (vendor.ownerName.isNotEmpty) 'ownerName': vendor.ownerName,
        if (vendor.city.isNotEmpty) 'city': vendor.city,
        if (vendor.locality != null) 'locality': vendor.locality,
        if (vendor.latitude != null) 'latitude': vendor.latitude,
        if (vendor.longitude != null) 'longitude': vendor.longitude,
        if (vendor.gstNumber != null && vendor.gstNumber!.isNotEmpty) 'gstNumber': vendor.gstNumber,
        if (vendor.panNumber != null && vendor.panNumber!.isNotEmpty) 'panNumber': vendor.panNumber,
      },
    );

    final data = Map<String, dynamic>.from(response.data);

    // Normalize verificationStatus field
    if (data['verificationStatus'] == null && data['status'] != null) {
      data['verificationStatus'] = data['status'].toString().toLowerCase();
    } else if (data['verificationStatus'] != null) {
      data['verificationStatus'] = data['verificationStatus'].toString().toLowerCase();
    } else {
      data['verificationStatus'] = vendor.verificationStatus;
    }

    // Preserve phone/email from current model or nested user object
    if (data['phone'] == null || data['phone'].toString().isEmpty) {
      data['phone'] = data['user']?['phone'] ?? vendor.phone;
    }
    if (data['email'] == null) {
      data['email'] = data['user']?['email'] ?? vendor.email;
    }

    return VendorModel.fromJson(data);
  }
}
