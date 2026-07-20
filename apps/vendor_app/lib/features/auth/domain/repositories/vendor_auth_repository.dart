import 'package:models/models.dart';

abstract class VendorAuthRepository {
  Future<void> sendOtp(String phone);
  Future<VendorModel?> verifyOtp(String phone, String otp);
}
