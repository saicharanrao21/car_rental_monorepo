import 'package:models/models.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String phone);
  Future<UserModel?> verifyOtp(String phone, String otp);
  Future<UserModel> registerUser({
    required String phone,
    required String name,
    String? email,
  });
}
