import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/admin_customer_repository.dart';
import '../../data/api_admin_customer_repository.dart';
import '../../../../core/providers/api_providers.dart';

final adminCustomerRepositoryProvider = Provider<AdminCustomerRepository>((ref) {
  return ApiAdminCustomerRepository(apiClient: ref.watch(apiClientProvider));
});

// Search Filter
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

// List Provider watching filters
final adminCustomersProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(adminCustomerRepositoryProvider);
  final search = ref.watch(customerSearchQueryProvider);

  return repo.getCustomers(searchQuery: search);
});

// Customer Detail Bundle
class CustomerDetailBundle {
  final UserModel profile;
  final List<BookingModel> bookingHistory;

  const CustomerDetailBundle({
    required this.profile,
    required this.bookingHistory,
  });
}

// Family Provider for details
final customerDetailBundleProvider = FutureProvider.family<CustomerDetailBundle, String>((ref, customerId) async {
  final repo = ref.watch(adminCustomerRepositoryProvider);

  final profile = await repo.getCustomerById(customerId);
  final bookingHistory = await repo.getBookingHistoryForCustomer(customerId);

  return CustomerDetailBundle(
    profile: profile,
    bookingHistory: bookingHistory,
  );
});

// Controller for customer actions
class AdminCustomerController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AdminCustomerController(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggleCustomerBanned(String id, bool banned) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(adminCustomerRepositoryProvider).setCustomerBanned(id, banned);
      _ref.invalidate(adminCustomersProvider);
      _ref.invalidate(customerDetailBundleProvider(id));
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminCustomerControllerProvider = StateNotifierProvider<AdminCustomerController, AsyncValue<void>>((ref) {
  return AdminCustomerController(ref);
});
