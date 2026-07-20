import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/vendor_registration_repository.dart';
import '../presentation/providers/registration_providers.dart';

class ApiVendorRegistrationRepository implements VendorRegistrationRepository {
  final ApiClient apiClient;

  ApiVendorRegistrationRepository({required this.apiClient});

  @override
  Future<VendorModel> registerVendor(VendorRegistrationDraft draft) async {
    final backendBusinessType = draft.businessType == 'Individual Owner' || draft.businessType.toLowerCase() == 'individual'
        ? 'INDIVIDUAL'
        : 'CONSULTANCY';

    final response = await apiClient.dio.post(
      '/auth/register-vendor',
      data: {
        'phone': draft.phone,
        'businessName': draft.businessName,
        'ownerName': draft.ownerName,
        'city': draft.city,
        if (draft.gstNumber.isNotEmpty) 'gstNumber': draft.gstNumber,
        if (draft.panNumber.isNotEmpty) 'panNumber': draft.panNumber,
        'bankDetails': '${draft.bankAccountNumber} - ${draft.bankIfsc} - ${draft.bankHolderName}',
        'businessType': backendBusinessType,
        'yearsInOperation': draft.yearsInOperation,
      },
    );

    final data = response.data;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;

    if (accessToken != null) {
      await apiClient.tokenStorage.setAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await apiClient.tokenStorage.setRefreshToken(refreshToken);
    }

    final userJson = Map<String, dynamic>.from(data['user']);
    final vendorJson = Map<String, dynamic>.from(userJson['vendor']);

    // Map phone and email from parent user if not present on vendor object
    vendorJson['phone'] ??= userJson['phone'] ?? draft.phone;
    vendorJson['email'] ??= userJson['email'] ?? draft.email;

    return VendorModel.fromJson(vendorJson);
  }
}
