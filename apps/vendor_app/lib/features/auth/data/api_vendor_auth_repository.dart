import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/vendor_auth_repository.dart';

class ApiVendorAuthRepository implements VendorAuthRepository {
  final ApiClient apiClient;

  ApiVendorAuthRepository({required this.apiClient});

  @override
  Future<void> sendOtp(String phone) async {
    await apiClient.dio.post(
      '/auth/otp/send',
      data: {'phone': phone},
    );
  }

  @override
  Future<VendorModel?> verifyOtp(String phone, String otp) async {
    final response = await apiClient.dio.post(
      '/auth/otp/verify',
      data: {
        'phone': phone,
        'otp': otp,
      },
    );

    final data = response.data;
    if (data['isNewUser'] == true) {
      return null;
    }

    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;

    if (accessToken != null) {
      await apiClient.tokenStorage.setAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await apiClient.tokenStorage.setRefreshToken(refreshToken);
    }

    final userJson = Map<String, dynamic>.from(data['user']);
    final role = userJson['role'] as String?;

    if (role != null && role != 'VENDOR') {
      await apiClient.tokenStorage.clearTokens();
      throw Exception(
        'This phone number is registered as a customer account. Please use the Customer App to sign in, or use a different number to register as a DriveGo partner.',
      );
    }

    if (role == 'VENDOR') {
      var vendorJson = userJson['vendor'] != null 
          ? Map<String, dynamic>.from(userJson['vendor'])
          : null;
          
      // If vendor record is not included, fetch /auth/me
      if (vendorJson == null) {
        try {
          final meResponse = await apiClient.dio.get('/auth/me');
          final meData = meResponse.data;
          if (meData['vendor'] != null) {
            vendorJson = Map<String, dynamic>.from(meData['vendor']);
            vendorJson['phone'] ??= meData['phone'];
            vendorJson['email'] ??= meData['email'];
          }
        } catch (e) {
          // Ignore
        }
      } else {
        vendorJson['phone'] ??= userJson['phone'] ?? phone;
        vendorJson['email'] ??= userJson['email'];
      }
      
      if (vendorJson != null) {
        return VendorModel.fromJson(vendorJson);
      }
    }

    return null;
  }
}
