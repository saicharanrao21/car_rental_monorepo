import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import '../../domain/repositories/support_repository.dart';
import '../../data/api_support_repository.dart';
import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/session_provider.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiSupportRepository(apiClient: apiClient);
});

final mySupportTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicketModel>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated || session.user == null) {
    return [];
  }
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getMyTickets();
});

final supportTicketDetailProvider =
    FutureProvider.family.autoDispose<SupportTicketModel, String>((ref, ticketId) async {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getTicketById(ticketId);
});
