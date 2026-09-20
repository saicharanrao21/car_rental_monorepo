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

    // Upload documents if selected in draft
    try {
      if (draft.tradeLicensePath != null && draft.tradeLicensePath!.isNotEmpty) {
        await apiClient.dio.post('/vendors/me/documents', data: {
          'type': 'TRADE_LICENSE',
          'fileUrl': draft.tradeLicensePath,
        });
      }
      if (draft.insurancePath != null && draft.insurancePath!.isNotEmpty) {
        await apiClient.dio.post('/vendors/me/documents', data: {
          'type': 'INSURANCE',
          'fileUrl': draft.insurancePath,
        });
      }
      if (draft.rcBookPath != null && draft.rcBookPath!.isNotEmpty) {
        await apiClient.dio.post('/vendors/me/documents', data: {
          'type': 'RC_BOOK',
          'fileUrl': draft.rcBookPath,
        });
      }
    } catch (_) {
      // Non-blocking: document upload failure during initial registration should not block vendor creation
    }

    final userJson = Map<String, dynamic>.from(data['user']);
    final vendorJson = Map<String, dynamic>.from(userJson['vendor']);

    // Map phone and email from parent user if not present on vendor object
    vendorJson['phone'] ??= userJson['phone'] ?? draft.phone;
    vendorJson['email'] ??= userJson['email'] ?? draft.email;

    return VendorModel.fromJson(vendorJson);
  }
}
