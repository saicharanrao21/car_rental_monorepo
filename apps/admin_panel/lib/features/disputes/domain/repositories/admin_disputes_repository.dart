import '../dispute_model.dart';

abstract interface class AdminDisputesRepository {
  Future<List<DisputeModel>> getDisputes({String? status});

  Future<DisputeModel> getDisputeById(String id);

  Future<void> updateDisputeStatus({
    required String id,
    required String status, // UNDER_REVIEW, RESOLVED, REJECTED
    String? resolutionNote,
  });
}
