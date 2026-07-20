import 'dart:math';
import 'package:models/models.dart';
import 'mock_data.dart';

mixin LatencySimulator {
  final Random _random = Random();

  Future<void> simulateLatency() async {
    final delayMs = 300 + _random.nextInt(500);
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}

class MockUserRepository with LatencySimulator {
  Future<UserModel?> getUserById(String id) async {
    await simulateLatency();
    try {
      return MockData.customers.firstWhere((u) => u.id == id);
    } catch (_) {
      try {
        final vendor = MockData.vendors.firstWhere((v) => v.id == id);
        return UserModel(
          id: vendor.id,
          name: vendor.ownerName,
          phone: '9876543200',
          email: '${vendor.ownerName.toLowerCase().replaceAll(' ', '.')}@example.com',
          role: 'vendor',
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    await simulateLatency();
    final List<UserModel> users = List.from(MockData.customers);
    for (var vendor in MockData.vendors) {
      users.add(UserModel(
        id: vendor.id,
        name: vendor.ownerName,
        phone: '9876543200',
        email: '${vendor.ownerName.toLowerCase().replaceAll(' ', '.')}@example.com',
        role: 'vendor',
      ));
    }
    return users;
  }
}

class MockVendorRepository with LatencySimulator {
  Future<VendorModel?> getVendorById(String id) async {
    await simulateLatency();
    try {
      return MockData.vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<VendorModel>> getVendorsByCity(String city) async {
    await simulateLatency();
    return MockData.vendors
        .where((v) => v.city.toLowerCase() == city.toLowerCase())
        .toList();
  }

  Future<List<VendorModel>> getAllVendors() async {
    await simulateLatency();
    return MockData.vendors;
  }
}

class MockCarRepository with LatencySimulator {
  Future<CarModel?> getCarById(String id) async {
    await simulateLatency();
    try {
      return MockData.cars.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<CarModel>> getCarsByCity(String city) async {
    await simulateLatency();
    final vendorIdsInCity = MockData.vendors
        .where((v) => v.city.toLowerCase() == city.toLowerCase())
        .map((v) => v.id)
        .toSet();
    return MockData.cars
        .where((car) => vendorIdsInCity.contains(car.vendorId))
        .toList();
  }

  Future<List<CarModel>> getCarsByVendor(String vendorId) async {
    await simulateLatency();
    return MockData.cars.where((c) => c.vendorId == vendorId).toList();
  }

  Future<List<CarModel>> getAllCars() async {
    await simulateLatency();
    return MockData.cars;
  }
}

class MockBookingRepository with LatencySimulator {
  Future<BookingModel?> getBookingById(String id) async {
    await simulateLatency();
    try {
      return MockData.bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<BookingModel>> getBookingsByCustomer(String customerId) async {
    await simulateLatency();
    return MockData.bookings.where((b) => b.customerId == customerId).toList();
  }

  Future<List<BookingModel>> getBookingsByVendor(String vendorId) async {
    await simulateLatency();
    return MockData.bookings.where((b) => b.vendorId == vendorId).toList();
  }

  Future<List<BookingModel>> getAllBookings() async {
    await simulateLatency();
    return MockData.bookings;
  }
}

class MockReviewRepository with LatencySimulator {
  Future<List<ReviewModel>> getReviewsByVendor(String vendorId) async {
    await simulateLatency();
    return MockData.reviews.where((r) => r.vendorId == vendorId).toList();
  }

  Future<List<ReviewModel>> getReviewsByBooking(String bookingId) async {
    await simulateLatency();
    return MockData.reviews.where((r) => r.bookingId == bookingId).toList();
  }

  Future<List<ReviewModel>> getAllReviews() async {
    await simulateLatency();
    return MockData.reviews;
  }
}

class MockEarningRepository with LatencySimulator {
  Future<List<EarningsModel>> getEarningsByVendor(String vendorId) async {
    await simulateLatency();
    return MockData.earnings.where((e) => e.vendorId == vendorId).toList();
  }

  Future<List<EarningsModel>> getAllEarnings() async {
    await simulateLatency();
    return MockData.earnings;
  }
}

class MockNotificationRepository with LatencySimulator {
  Future<List<NotificationModel>> getNotificationsByUser(String userId) async {
    await simulateLatency();
    return MockData.notifications.where((n) => n.userId == userId).toList();
  }
}

class MockBannerRepository with LatencySimulator {
  Future<List<BannerModel>> getActiveBanners() async {
    await simulateLatency();
    return MockData.banners.where((b) => b.isActive).toList();
  }
}
