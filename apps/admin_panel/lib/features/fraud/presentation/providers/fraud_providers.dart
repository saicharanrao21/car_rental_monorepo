import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/fraud/domain/repositories/fraud_repository.dart';
import 'package:admin_panel/features/fraud/data/api_fraud_repository.dart';

final fraudRepositoryProvider = Provider<FraudRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiFraudRepository(apiClient);
});

final fraudRiskLevelFilterProvider = StateProvider<String?>((ref) => null);
final fraudStatusFilterProvider = StateProvider<String?>((ref) => null);

final fraudSummaryProvider = FutureProvider<FraudSummaryModel>((ref) async {
  final repo = ref.watch(fraudRepositoryProvider);
  return repo.getSummary();
});

final fraudAssessmentsProvider =
    FutureProvider<List<RiskAssessmentModel>>((ref) async {
  final repo = ref.watch(fraudRepositoryProvider);
  final riskLevel = ref.watch(fraudRiskLevelFilterProvider);
  final status = ref.watch(fraudStatusFilterProvider);
  return repo.getAssessments(riskLevel: riskLevel, status: status);
});
