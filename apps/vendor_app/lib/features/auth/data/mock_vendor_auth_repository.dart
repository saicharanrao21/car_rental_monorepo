import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/vendor_auth_repository.dart';

class MockVendorAuthRepository implements VendorAuthRepository {
  @override
  Future<void> sendOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('OTP sent to $phone: 123456');
  }

  @override
  Future<VendorModel?> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (otp != '123456') {
      throw Exception('Invalid OTP. Please enter 123456.');
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return null;

    try {
      // Find matching mock vendor by phone number
      final vendor = MockData.vendors.firstWhere((v) {
        final cleanVendorPhone = v.phone.replaceAll(RegExp(r'\D'), '');
        if (cleanVendorPhone.isEmpty) return false;
        return cleanVendorPhone == cleanPhone ||
            cleanVendorPhone.endsWith(cleanPhone) ||
            cleanPhone.endsWith(cleanVendorPhone);
      });
      return vendor;
    } catch (_) {
      return null;
    }
  }
}
