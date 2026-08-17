import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('WhatsApp Models Tests', () {
    test('WhatsAppMessageModel serialization & deserialization with enums', () {
      final json = {
        'id': 'msg_101',
        'userId': 'usr_abc',
        'bookingId': 'bkg_xyz',
        'phoneNumber': '+919876543210',
        'templateName': 'booking_confirmed',
        'templateLanguage': 'en_US',
        'messageType': 'BOOKING_CONFIRMED',
        'status': 'DELIVERED',
        'providerMessageId': 'wamid.HBgL123',
        'idempotencyKey': 'whatsapp_booking_confirmed_bkg_xyz',
        'variables': {'customerName': 'Sai', 'totalFare': '5000'},
        'failureCode': null,
        'failureReason': null,
        'sentAt': '2026-08-17T08:00:00.000Z',
        'deliveredAt': '2026-08-17T08:00:05.000Z',
        'readAt': null,
        'failedAt': null,
        'createdAt': '2026-08-17T07:59:59.000Z',
      };

      final msg = WhatsAppMessageModel.fromJson(json);
      expect(msg.id, 'msg_101');
      expect(msg.messageType, WhatsAppMessageType.bookingConfirmed);
      expect(msg.status, WhatsAppMessageStatus.delivered);
      expect(msg.status.displayName, 'Delivered');
      expect(msg.messageType.displayName, 'Booking Confirmed');
      expect(msg.phoneNumber, '+919876543210');

      final outJson = msg.toJson();
      expect(outJson['id'], 'msg_101');
      expect(outJson['status'], 'DELIVERED');
      expect(outJson['messageType'], 'BOOKINGCONFIRMED');
    });

    test('WhatsAppSummaryModel serialization & deserialization', () {
      final json = {
        'totalMessages': 150,
        'sentCount': 20,
        'deliveredCount': 90,
        'readCount': 35,
        'failedCount': 5,
        'deliveryRatePercent': 83.3,
      };

      final summary = WhatsAppSummaryModel.fromJson(json);
      expect(summary.totalMessages, 150);
      expect(summary.deliveredCount, 90);
      expect(summary.readCount, 35);
      expect(summary.deliveryRatePercent, 83.3);

      final outJson = summary.toJson();
      expect(outJson['totalMessages'], 150);
      expect(outJson['deliveryRatePercent'], 83.3);
    });
  });
}
