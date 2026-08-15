import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({required this.tokenStorage, Dio? dio})
      : dio = dio ?? Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://drivego-staging-api.onrender.com',
            ),
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ) {
    this.dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await tokenStorage.getAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final requestPath = error.requestOptions.path;
            if (requestPath.contains('/auth/refresh') ||
                requestPath.contains('/auth/otp/verify') ||
                requestPath.contains('/auth/admin/login')) {
              return handler.next(error);
            }

            final refreshToken = await tokenStorage.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                // Call /auth/refresh with stored refresh token
                final refreshDio = Dio(BaseOptions(baseUrl: this.dio.options.baseUrl));
                final response = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  final newAccessToken = response.data['accessToken'] as String?;
                  final newRefreshToken = response.data['refreshToken'] as String?;

                  if (newAccessToken != null) {
                    await tokenStorage.setAccessToken(newAccessToken);
                    if (newRefreshToken != null) {
                      await tokenStorage.setRefreshToken(newRefreshToken);
                    }

                    // Retry original request
                    final options = error.requestOptions;
                    options.headers['Authorization'] = 'Bearer $newAccessToken';
                    
                    final retryResponse = await this.dio.fetch(options);
                    return handler.resolve(retryResponse);
                  }
                }
              } catch (e) {
                // If refresh fails, clear tokens and propagate error
                await tokenStorage.clearTokens();
                return handler.next(error);
              }
            }
            // No refresh token, clear tokens and propagate error
            await tokenStorage.clearTokens();
          }
          return handler.next(error);
        },
      ),
    );
  }
}
