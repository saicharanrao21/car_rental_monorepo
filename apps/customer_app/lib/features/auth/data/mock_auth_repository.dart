import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<void> sendOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('OTP sent to $phone: 123456');
  }

  @override
  Future<UserModel?> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (otp != '123456') {
      throw Exception('Invalid OTP. Please enter 123456.');
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    try {
      final customer = MockData.customers.firstWhere((c) {
        final cleanCustPhone = c.phone.replaceAll(RegExp(r'\D'), '');
        return cleanCustPhone == cleanPhone || cleanCustPhone.endsWith(cleanPhone) || cleanPhone.endsWith(cleanCustPhone);
      });
      return customer;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel> registerUser({
    required String phone,
    required String name,
    String? email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'cust_${DateTime.now().millisecondsSinceEpoch}';
    return UserModel(
      id: id,
      name: name,
      phone: phone,
      email: email,
      role: 'customer',
    );
  }
}
