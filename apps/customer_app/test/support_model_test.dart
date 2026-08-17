import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('SupportTicketModel Tests', () {
    test('SupportTicketModel.fromJson parses complete ticket data safely', () {
      final json = {
        'id': 'tkt_123',
        'ticketNumber': 'TKT-2026-08-00001',
        'customerId': 'cust_1',
        'customer': {'name': 'Rohan Sharma', 'phone': '+919876543210'},
        'category': 'BOOKING',
        'priority': 'HIGH',
        'subject': 'Delay in vehicle handover',
        'description': 'Vendor has not arrived at pickup location.',
        'status': 'OPEN',
        'createdAt': '2026-08-16T12:00:00.000Z',
        'updatedAt': '2026-08-16T12:00:00.000Z',
        'messages': [
          {
            'id': 'msg_1',
            'ticketId': 'tkt_123',
            'senderId': 'cust_1',
            'senderRole': 'CUSTOMER',
            'message': 'Vendor has not arrived.',
            'isInternal': false,
            'createdAt': '2026-08-16T12:00:00.000Z',
          }
        ],
      };

      final ticket = SupportTicketModel.fromJson(json);

      expect(ticket.id, 'tkt_123');
      expect(ticket.ticketNumber, 'TKT-2026-08-00001');
      expect(ticket.category, TicketCategory.BOOKING);
      expect(ticket.priority, TicketPriority.HIGH);
      expect(ticket.status, TicketStatus.OPEN);
      expect(ticket.messages.length, 1);
      expect(ticket.messages.first.message, 'Vendor has not arrived.');
    });

    test('SupportTicketModel.fromJson handles null and missing optional fields', () {
      final json = {
        'id': 'tkt_minimal',
        'ticketNumber': 'TKT-2026-08-00002',
        'customerId': 'cust_2',
        'category': 'OTHER',
        'subject': 'General Query',
        'description': 'Question',
        'status': 'OPEN',
      };

      final ticket = SupportTicketModel.fromJson(json);

      expect(ticket.id, 'tkt_minimal');
      expect(ticket.category, TicketCategory.OTHER);
      expect(ticket.priority, TicketPriority.NORMAL);
      expect(ticket.messages, isEmpty);
      expect(ticket.assignedToUserId, isNull);
    });
  });
}
