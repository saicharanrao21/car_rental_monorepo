import 'package:models/models.dart';

abstract interface class AdminCustomerRepository {
  Future<List<UserModel>> getCustomers({String? searchQuery});

  Future<UserModel> getCustomerById(String id);

  Future<List<BookingModel>> getBookingHistoryForCustomer(String id);

  Future<void> setCustomerBanned(String id, bool banned);
}
