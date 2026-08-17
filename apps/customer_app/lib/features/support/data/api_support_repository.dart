import 'package:core/core.dart';
import 'package:models/models.dart';
import '../domain/repositories/support_repository.dart';

class ApiSupportRepository implements SupportRepository {
  final ApiClient apiClient;

  ApiSupportRepository({required this.apiClient});

  @override
  Future<SupportTicketModel> createTicket({
    required TicketCategory category,
    TicketPriority priority = TicketPriority.NORMAL,
    required String subject,
    required String description,
    String? bookingId,
    List<String>? attachments,
  }) async {
    final response = await apiClient.dio.post('/support/tickets', data: {
      'category': category.name,
      'priority': priority.name,
      'subject': subject,
      'description': description,
      if (bookingId != null) 'bookingId': bookingId,
      if (attachments != null) 'attachments': attachments,
    });
    return SupportTicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<SupportTicketModel>> getMyTickets() async {
    final response = await apiClient.dio.get('/support/tickets/my');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SupportTicketModel> getTicketById(String ticketId) async {
    final response = await apiClient.dio.get('/support/tickets/$ticketId');
    return SupportTicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TicketMessageModel> replyTicket({
    required String ticketId,
    required String message,
    List<String>? attachments,
  }) async {
    final response = await apiClient.dio.post('/support/tickets/$ticketId/reply', data: {
      'message': message,
      if (attachments != null) 'attachments': attachments,
    });
    return TicketMessageModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SupportTicketModel> closeTicket(String ticketId) async {
    final response = await apiClient.dio.post('/support/tickets/$ticketId/close');
    return SupportTicketModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SupportTicketModel> reopenTicket({
    required String ticketId,
    required String reason,
  }) async {
    final response = await apiClient.dio.post('/support/tickets/$ticketId/reopen', data: {
      'reason': reason,
    });
    return SupportTicketModel.fromJson(response.data as Map<String, dynamic>);
  }
}
