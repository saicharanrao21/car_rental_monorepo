import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/vendor_registration_repository.dart';
import '../../data/api_vendor_registration_repository.dart';
import '../../../../core/providers/api_providers.dart';

final registrationPhoneProvider = StateProvider<String?>((ref) => null);

class VendorRegistrationDraft {
  final String ownerName;
  final String phone;
  final String email;
  final String businessName;
  final String city;
  final int yearsInOperation;
  final String businessType; // 'Individual Owner' | 'Consultancy'
  final String gstNumber;
  final String panNumber;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankHolderName;
  final String? rcBookPath;
  final String? tradeLicensePath;
  final String? insurancePath;

  const VendorRegistrationDraft({
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.businessName = '',
    this.city = 'Mumbai',
    this.yearsInOperation = 0,
    this.businessType = 'Individual Owner',
    this.gstNumber = '',
    this.panNumber = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankHolderName = '',
    this.rcBookPath,
    this.tradeLicensePath,
    this.insurancePath,
  });

  VendorRegistrationDraft copyWith({
    String? ownerName,
    String? phone,
    String? email,
    String? businessName,
    String? city,
    int? yearsInOperation,
    String? businessType,
    String? gstNumber,
    String? panNumber,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankHolderName,
    String? rcBookPath,
    String? tradeLicensePath,
    String? insurancePath,
  }) {
    return VendorRegistrationDraft(
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      city: city ?? this.city,
      yearsInOperation: yearsInOperation ?? this.yearsInOperation,
      businessType: businessType ?? this.businessType,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankHolderName: bankHolderName ?? this.bankHolderName,
      rcBookPath: rcBookPath ?? this.rcBookPath,
      tradeLicensePath: tradeLicensePath ?? this.tradeLicensePath,
      insurancePath: insurancePath ?? this.insurancePath,
    );
  }
}

class RegistrationStepNotifier extends StateNotifier<int> {
  RegistrationStepNotifier() : super(0);

  void next() => state = state + 1;
  void back() => state = state - 1;
  void goTo(int step) => state = step;
  void reset() => state = 0;
}

final registrationStepProvider =
    StateNotifierProvider.autoDispose<RegistrationStepNotifier, int>((ref) => RegistrationStepNotifier());

class VendorRegistrationNotifier extends StateNotifier<VendorRegistrationDraft> {
  VendorRegistrationNotifier() : super(const VendorRegistrationDraft());

  void updateDraft(VendorRegistrationDraft draft) {
    state = draft;
  }

  void updateField({
    String? ownerName,
    String? phone,
    String? email,
    String? businessName,
    String? city,
    int? yearsInOperation,
    String? businessType,
    String? gstNumber,
    String? panNumber,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankHolderName,
    String? rcBookPath,
    String? tradeLicensePath,
    String? insurancePath,
  }) {
    state = state.copyWith(
      ownerName: ownerName,
      phone: phone,
      email: email,
      businessName: businessName,
      city: city,
      yearsInOperation: yearsInOperation,
      businessType: businessType,
      gstNumber: gstNumber,
      panNumber: panNumber,
      bankAccountNumber: bankAccountNumber,
      bankIfsc: bankIfsc,
      bankHolderName: bankHolderName,
      rcBookPath: rcBookPath,
      tradeLicensePath: tradeLicensePath,
      insurancePath: insurancePath,
    );
  }

  void reset() {
    state = const VendorRegistrationDraft();
  }
}

final vendorRegistrationDraftProvider =
    StateNotifierProvider.autoDispose<VendorRegistrationNotifier, VendorRegistrationDraft>(
        (ref) => VendorRegistrationNotifier());

final vendorRegistrationRepositoryProvider = Provider<VendorRegistrationRepository>((ref) {
  return ApiVendorRegistrationRepository(apiClient: ref.watch(apiClientProvider));
});
