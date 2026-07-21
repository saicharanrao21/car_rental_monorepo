import 'package:core/core.dart';
import 'package:dio/dio.dart';
import '../domain/repositories/admin_auth_repository.dart';

class ApiAdminAuthRepository implements AdminAuthRepository {
  final ApiClient apiClient;

  ApiAdminAuthRepository({required this.apiClient});

  @override
  Future<bool> login(String email, String password) async {
    try {
      final response = await apiClient.dio.post('/auth/admin/login', data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;

        if (accessToken != null && refreshToken != null) {
          await apiClient.tokenStorage.setAccessToken(accessToken);
          await apiClient.tokenStorage.setRefreshToken(refreshToken);
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      if (msg != null) {
        throw Exception(msg is List ? msg.join(', ') : msg);
      }
      throw Exception('Login failed. Please check your credentials.');
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }
}
