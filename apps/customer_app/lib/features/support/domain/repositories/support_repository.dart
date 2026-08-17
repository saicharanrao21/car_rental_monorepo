import 'package:models/models.dart';

abstract class SupportRepository {
  Future<SupportTicketModel> createTicket({
    required TicketCategory category,
    TicketPriority priority = TicketPriority.NORMAL,
    required String subject,
    required String description,
    String? bookingId,
    List<String>? attachments,
  });

  Future<List<SupportTicketModel>> getMyTickets();

  Future<SupportTicketModel> getTicketById(String ticketId);

  Future<TicketMessageModel> replyTicket({
    required String ticketId,
    required String message,
    List<String>? attachments,
  });

  Future<SupportTicketModel> closeTicket(String ticketId);

  Future<SupportTicketModel> reopenTicket({
    required String ticketId,
    required String reason,
  });
}
