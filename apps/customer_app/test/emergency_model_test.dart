import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('EmergencyRequestModel Tests', () {
    test('EmergencyRequestModel.fromJson parses incident correctly', () {
      final json = {
        'id': 'emg_1',
        'requestNumber': 'SOS-2026-08-00001',
        'bookingId': 'bk_1',
        'customerId': 'cust_1',
        'vendorId': 'vend_1',
        'carId': 'car_1',
        'incidentType': 'FLAT_TYRE',
        'status': 'PROVIDER_EN_ROUTE',
        'urgency': 'URGENT',
        'customerNotes': 'Right front tyre flat',
        'latitude': 19.0760,
        'longitude': 72.8777,
        'locationAddress': 'Mumbai Highway Toll',
        'assignedProviderName': 'Highway Rescue Services',
        'assignedProviderPhone': '+919988776655',
        'estimatedEtaMinutes': 25,
        'createdAt': '2026-08-16T12:30:00.000Z',
      };

      final emg = EmergencyRequestModel.fromJson(json);

      expect(emg.id, 'emg_1');
      expect(emg.requestNumber, 'SOS-2026-08-00001');
      expect(emg.incidentType, IncidentType.FLAT_TYRE);
      expect(emg.status, EmergencyStatus.PROVIDER_EN_ROUTE);
      expect(emg.assignedProviderName, 'Highway Rescue Services');
      expect(emg.estimatedEtaMinutes, 25);
    });
  });
}
