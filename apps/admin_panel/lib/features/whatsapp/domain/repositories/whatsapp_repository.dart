import 'package:models/models.dart';

abstract class WhatsAppRepository {
  Future<WhatsAppSummaryModel> getSummary();
  Future<List<WhatsAppMessageModel>> getMessages({
    WhatsAppMessageStatus? status,
    WhatsAppMessageType? messageType,
    String? search,
    int? skip,
    int? take,
  });
  Future<WhatsAppMessageModel> resendMessage(String id);
  Future<List<Map<String, dynamic>>> getTemplates();
  Future<WhatsAppMessageModel> sendManualMessage({
    required String phoneNumber,
    required String templateName,
    Map<String, dynamic>? variables,
    String? bookingId,
    String? userId,
  });
  Future<Map<String, dynamic>> getMessageTimeline(String id);
}
