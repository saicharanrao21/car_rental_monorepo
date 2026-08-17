import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/whatsapp/domain/repositories/whatsapp_repository.dart';
import 'package:admin_panel/features/whatsapp/data/api_whatsapp_repository.dart';

final whatsAppRepositoryProvider = Provider<WhatsAppRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiWhatsAppRepository(apiClient);
});

final whatsAppStatusFilterProvider = StateProvider<WhatsAppMessageStatus?>((ref) => null);
final whatsAppTypeFilterProvider = StateProvider<WhatsAppMessageType?>((ref) => null);
final whatsAppSearchQueryProvider = StateProvider<String>((ref) => '');

final whatsAppSummaryProvider = FutureProvider<WhatsAppSummaryModel>((ref) async {
  final repo = ref.watch(whatsAppRepositoryProvider);
  return repo.getSummary();
});

final whatsAppMessagesProvider = FutureProvider<List<WhatsAppMessageModel>>((ref) async {
  final repo = ref.watch(whatsAppRepositoryProvider);
  final status = ref.watch(whatsAppStatusFilterProvider);
  final messageType = ref.watch(whatsAppTypeFilterProvider);
  final search = ref.watch(whatsAppSearchQueryProvider);

  return repo.getMessages(
    status: status,
    messageType: messageType,
    search: search,
  );
});
