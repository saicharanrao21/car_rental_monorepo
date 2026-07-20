import '../domain/repositories/admin_auth_repository.dart';

class MockAdminAuthRepository implements AdminAuthRepository {
  @override
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail == 'admin@platform.com' && password == 'Admin@123') {
      return true;
    } else {
      throw Exception('Invalid email or password. Please use admin@platform.com and Admin@123.');
    }
  }
}
