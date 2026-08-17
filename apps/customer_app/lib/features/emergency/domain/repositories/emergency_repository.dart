import 'package:models/models.dart';

abstract class EmergencyRepository {
  Future<EmergencyRequestModel> createEmergencyRequest({
    required String bookingId,
    required IncidentType incidentType,
    String urgency = 'URGENT',
    String? customerNotes,
    double? latitude,
    double? longitude,
    String? locationAddress,
  });

  Future<EmergencyRequestModel?> getActiveRequestForBooking(String bookingId);

  Future<List<EmergencyRequestModel>> getMyRequests();
}
