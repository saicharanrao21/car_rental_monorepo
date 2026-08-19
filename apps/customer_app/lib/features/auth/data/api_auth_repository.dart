import 'package:models/models.dart';
import 'package:core/core.dart';
import '../domain/repositories/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient apiClient;

  ApiAuthRepository({required this.apiClient});

  @override
  Future<void> sendOtp(String phone) async {
    await apiClient.dio.post(
      '/auth/otp/send',
      data: {'phone': phone},
    );
  }

  @override
  Future<UserModel?> verifyOtp(String phone, String otp) async {
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
    if (userJson['profilePhotoUrl'] != null && userJson['profilePhoto'] == null) {
      userJson['profilePhoto'] = userJson['profilePhotoUrl'];
    }

    return UserModel.fromJson(userJson);
  }

  @override
  Future<UserModel> registerUser({
    required String phone,
    required String name,
    String? email,
  }) async {
    final response = await apiClient.dio.post(
      '/auth/register',
      data: {
        'phone': phone,
        'name': name,
        if (email != null) 'email': email,
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
    if (userJson['profilePhotoUrl'] != null && userJson['profilePhoto'] == null) {
      userJson['profilePhoto'] = userJson['profilePhotoUrl'];
    }

    return UserModel.fromJson(userJson);
  }
}
