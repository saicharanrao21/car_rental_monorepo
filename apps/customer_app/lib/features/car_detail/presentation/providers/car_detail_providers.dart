import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/car_detail_repository.dart';
import '../../data/api_car_detail_repository.dart';
import '../../../../core/providers/api_providers.dart';

final carDetailRepositoryProvider = Provider<CarDetailRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiCarDetailRepository(apiClient: apiClient);
});

class CarDetailData {
  final CarModel car;
  final VendorModel vendor;
  final List<ReviewModel> reviews;

  CarDetailData({
    required this.car,
    required this.vendor,
    required this.reviews,
  });
}

final carDetailDataProvider = FutureProvider.family.autoDispose<CarDetailData, String>((ref, carId) async {
  final repository = ref.watch(carDetailRepositoryProvider);

  final car = await repository.getCarById(carId);

  VendorModel vendor;
  try {
    vendor = await repository.getVendorById(car.vendorId);
  } catch (_) {
    vendor = VendorModel(
      id: car.vendorId.isNotEmpty ? car.vendorId : 'v-default',
      businessName: 'Verified Partner',
      ownerName: 'Verified Partner',
      phone: '+91 9876543210',
      email: 'vendor@driveease.com',
      city: 'Mumbai',
      rating: 4.8,
      totalTrips: 120,
    );
  }

  List<ReviewModel> reviews = [];
  try {
    reviews = await repository.getReviewsForVendor(car.vendorId);
  } catch (_) {
    reviews = [];
  }

  return CarDetailData(
    car: car,
    vendor: vendor,
    reviews: reviews,
  );
});
