import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../../data/api_emergency_repository.dart';
import '../../../../core/providers/api_providers.dart';

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiEmergencyRepository(apiClient: apiClient);
});

final activeBookingEmergencyProvider = FutureProvider.family
    .autoDispose<EmergencyRequestModel?, String>((ref, bookingId) async {
  final repo = ref.watch(emergencyRepositoryProvider);
  return repo.getActiveRequestForBooking(bookingId);
});
