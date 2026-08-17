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
}
