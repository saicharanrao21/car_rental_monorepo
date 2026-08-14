import 'package:models/models.dart';
import '../dispute_model.dart';

abstract interface class AdminDisputesRepository {
  Future<List<DisputeModel>> getDisputes({String? status});

  Future<DisputeModel> getDisputeById(String id);

  Future<void> updateDisputeStatus({
    required String id,
    required String status, // UNDER_REVIEW, RESOLVED, REJECTED
    String? resolutionNote,
  });

  Future<List<DamageClaimModel>> getDamageClaims({String? status});

  Future<DamageClaimModel> adjudicateDamageClaim({
    required String claimId,
    required String decision, // APPROVED, PARTIALLY_APPROVED, REJECTED
    double? approvedAmount,
    required String adminNotes,
  });
}
