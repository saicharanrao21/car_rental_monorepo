import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/emergency_repository.dart';

class ApiEmergencyRepository implements EmergencyRepository {
  final ApiClient apiClient;

  ApiEmergencyRepository({required this.apiClient});

  @override
  Future<EmergencyRequestModel> createEmergencyRequest({
    required String bookingId,
    required IncidentType incidentType,
    String urgency = 'URGENT',
    String? customerNotes,
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    final response = await apiClient.dio.post('/emergency/requests', data: {
      'bookingId': bookingId,
      'incidentType': incidentType.name,
      'urgency': urgency,
      if (customerNotes != null) 'customerNotes': customerNotes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAddress != null) 'locationAddress': locationAddress,
    });
    return EmergencyRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<EmergencyRequestModel?> getActiveRequestForBooking(String bookingId) async {
    try {
      final response =
          await apiClient.dio.get('/emergency/requests/booking/$bookingId');
      if (response.data == null) return null;
      return EmergencyRequestModel.fromJson(
          response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EmergencyRequestModel>> getMyRequests() async {
    final response = await apiClient.dio.get('/emergency/requests/my');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => EmergencyRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
