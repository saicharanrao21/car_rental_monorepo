import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/admin_customer_repository.dart';

class MockAdminCustomerRepository with LatencySimulator implements AdminCustomerRepository {
  @override
  Future<List<UserModel>> getCustomers({String? searchQuery}) async {
    await simulateLatency();

    var list = MockData.customers.where((u) => u.role == 'customer').toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((c) =>
          c.name.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  @override
  Future<UserModel> getCustomerById(String id) async {
    await simulateLatency();
    return MockData.customers.firstWhere(
      (c) => c.id == id && c.role == 'customer',
      orElse: () => throw Exception('Customer not found with id: $id'),
    );
  }

  @override
  Future<List<BookingModel>> getBookingHistoryForCustomer(String id) async {
    await simulateLatency();
    final list = MockData.bookings.where((b) => b.customerId == id).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> setCustomerBanned(String id, bool banned) async {
    await simulateLatency();
    final idx = MockData.customers.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final old = MockData.customers[idx];
      MockData.customers[idx] = old.copyWith(banned: banned);
    }
  }
}
