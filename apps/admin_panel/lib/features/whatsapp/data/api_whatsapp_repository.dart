import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/whatsapp_repository.dart';

class ApiWhatsAppRepository implements WhatsAppRepository {
  final ApiClient _apiClient;

  ApiWhatsAppRepository(this._apiClient);

  @override
  Future<WhatsAppSummaryModel> getSummary() async {
    final response = await _apiClient.dio.get('/admin/whatsapp/summary');
    return WhatsAppSummaryModel.fromJson(response.data);
  }

  @override
  Future<List<WhatsAppMessageModel>> getMessages({
    WhatsAppMessageStatus? status,
    WhatsAppMessageType? messageType,
    String? search,
    int? skip,
    int? take,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status.name.toUpperCase();
    if (messageType != null) queryParams['messageType'] = messageType.name.toUpperCase();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (skip != null) queryParams['skip'] = skip;
    if (take != null) queryParams['take'] = take;

    final response = await _apiClient.dio.get(
      '/admin/whatsapp/messages',
      queryParameters: queryParams,
    );

    final rawItems = response.data['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((e) => WhatsAppMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WhatsAppMessageModel> resendMessage(String id) async {
    final response = await _apiClient.dio.post('/admin/whatsapp/resend/$id');
    return WhatsAppMessageModel.fromJson(response.data);
  }
}
