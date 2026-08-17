import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Fraud Models Tests', () {
    test('RiskSignalModel serialization & deserialization', () {
      final json = {
        'code': 'DUPLICATE_DRIVING_LICENCE',
        'description': 'Driving licence registered on another account',
        'scoreDelta': 40,
      };

      final model = RiskSignalModel.fromJson(json);
      expect(model.code, 'DUPLICATE_DRIVING_LICENCE');
      expect(model.scoreDelta, 40);

      final out = model.toJson();
      expect(out['code'], 'DUPLICATE_DRIVING_LICENCE');
      expect(out['scoreDelta'], 40);
    });

    test('RiskAssessmentModel serialization & deserialization with enums', () {
      final json = {
        'id': 'log_risk_101',
        'userId': 'usr_fraudster',
        'userName': 'Scam User',
        'userPhone': '+919999888877',
        'score': 85,
        'riskLevel': 'CRITICAL',
        'action': 'BLOCK',
        'signals': [
          {
            'code': 'BANNED_USER',
            'description': 'User account banned',
            'scoreDelta': 100,
          }
        ],
        'status': 'PENDING_REVIEW',
        'adminNotes': 'Under manual investigation',
        'resolvedBy': null,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'resolvedAt': null,
      };

      final model = RiskAssessmentModel.fromJson(json);
      expect(model.id, 'log_risk_101');
      expect(model.score, 85);
      expect(model.riskLevel, RiskLevel.critical);
      expect(model.action, RiskAction.block);
      expect(model.signals.length, 1);
      expect(model.signals.first.code, 'BANNED_USER');

      final out = model.toJson();
      expect(out['id'], 'log_risk_101');
      expect(out['riskLevel'], 'CRITICAL');
      expect(out['action'], 'BLOCK');
    });

    test('FraudSummaryModel serialization & deserialization', () {
      final json = {
        'totalEvents': 45,
        'criticalCount': 5,
        'highCount': 10,
        'mediumCount': 15,
        'lowCount': 15,
        'pendingReviewCount': 8,
      };

      final model = FraudSummaryModel.fromJson(json);
      expect(model.totalEvents, 45);
      expect(model.criticalCount, 5);
      expect(model.pendingReviewCount, 8);

      final out = model.toJson();
      expect(out['totalEvents'], 45);
      expect(out['criticalCount'], 5);
    });
  });
}
