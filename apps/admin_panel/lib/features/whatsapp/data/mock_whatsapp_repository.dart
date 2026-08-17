import 'package:models/models.dart';
import 'package:mock_data/mock_data.dart';
import '../domain/repositories/whatsapp_repository.dart';

class MockWhatsAppRepository with LatencySimulator implements WhatsAppRepository {
  final List<WhatsAppMessageModel> _messages = [
    WhatsAppMessageModel(
      id: 'msg_mock_1',
      userId: 'usr_mock_1',
      bookingId: 'cmsu5sk3m000qgw1zaf9ftksz',
      phoneNumber: '+919876543210',
      templateName: 'booking_confirmed',
      templateLanguage: 'en_US',
      messageType: WhatsAppMessageType.bookingConfirmed,
      status: WhatsAppMessageStatus.delivered,
      providerMessageId: 'wamid.mock_receipt_001',
      idempotencyKey: 'whatsapp_booking_confirmed_cmsu5sk3m000qgw1zaf9ftksz',
      variables: {
        'customerName': 'Sai Charan',
        'bookingId': 'cmsu5sk3m000qgw1zaf9ftksz',
        'carName': 'Hyundai Creta (AT)',
        'totalFare': '5000',
      },
      sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
      deliveredAt: DateTime.now().subtract(const Duration(minutes: 29)),
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    WhatsAppMessageModel(
      id: 'msg_mock_2',
      userId: 'usr_mock_2',
      bookingId: 'bkg_test_999',
      phoneNumber: '+919876543211',
      templateName: 'payment_successful',
      templateLanguage: 'en_US',
      messageType: WhatsAppMessageType.paymentSuccessful,
      status: WhatsAppMessageStatus.read,
      providerMessageId: 'wamid.mock_receipt_002',
      idempotencyKey: 'whatsapp_payment_success_pay_test_999',
      variables: {
        'customerName': 'Priya Reddy',
        'amount': '2500',
      },
      sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      deliveredAt: DateTime.now().subtract(const Duration(hours: 2)),
      readAt: DateTime.now().subtract(const Duration(hours: 1)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    WhatsAppMessageModel(
      id: 'msg_mock_3',
      userId: 'usr_mock_3',
      bookingId: 'bkg_test_888',
      phoneNumber: '+919876543212',
      templateName: 'booking_cancelled',
      templateLanguage: 'en_US',
      messageType: WhatsAppMessageType.bookingCancelled,
      status: WhatsAppMessageStatus.failed,
      providerMessageId: 'wamid.mock_receipt_003',
      idempotencyKey: 'whatsapp_booking_cancelled_bkg_test_888',
      failureCode: '131026',
      failureReason: 'Receiver phone number not reachable',
      failedAt: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<WhatsAppSummaryModel> getSummary() async {
    await simulateLatency();
    final total = _messages.length;
    final sent = _messages.where((m) => m.status == WhatsAppMessageStatus.sent).length;
    final delivered = _messages.where((m) => m.status == WhatsAppMessageStatus.delivered).length;
    final read = _messages.where((m) => m.status == WhatsAppMessageStatus.read).length;
    final failed = _messages.where((m) => m.status == WhatsAppMessageStatus.failed).length;

    return WhatsAppSummaryModel(
      totalMessages: total,
      sentCount: sent,
      deliveredCount: delivered,
      readCount: read,
      failedCount: failed,
      deliveryRatePercent: total > 0 ? ((delivered + read) / total) * 100 : 100.0,
    );
  }

  @override
  Future<List<WhatsAppMessageModel>> getMessages({
    WhatsAppMessageStatus? status,
    WhatsAppMessageType? messageType,
    String? search,
    int? skip,
    int? take,
  }) async {
    await simulateLatency();
    return _messages.where((m) {
      if (status != null && m.status != status) return false;
      if (messageType != null && m.messageType != messageType) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return m.phoneNumber.contains(q) ||
            (m.bookingId?.toLowerCase().contains(q) ?? false) ||
            m.templateName.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Future<WhatsAppMessageModel> resendMessage(String id) async {
    await simulateLatency();
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) throw Exception('Message not found');

    final updated = WhatsAppMessageModel(
      id: _messages[index].id,
      userId: _messages[index].userId,
      bookingId: _messages[index].bookingId,
      phoneNumber: _messages[index].phoneNumber,
      templateName: _messages[index].templateName,
      templateLanguage: _messages[index].templateLanguage,
      messageType: _messages[index].messageType,
      status: WhatsAppMessageStatus.sent,
      providerMessageId: 'wamid.mock_resend_${DateTime.now().millisecondsSinceEpoch}',
      idempotencyKey: _messages[index].idempotencyKey,
      variables: _messages[index].variables,
      sentAt: DateTime.now(),
      createdAt: _messages[index].createdAt,
    );

    _messages[index] = updated;
    return updated;
  }
}
