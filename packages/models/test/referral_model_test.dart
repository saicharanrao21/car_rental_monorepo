import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Referral Models Tests', () {
    test('ReferralCampaignModel.fromJson parses campaign payload correctly', () {
      final json = {
        'id': 'cmp_123',
        'name': 'Festive Referral Campaign',
        'code': 'FESTIVE2026',
        'referrerRewardAmount': 300.0,
        'refereeRewardAmount': 300.0,
        'minBookingAmount': 1500.0,
        'city': 'Mumbai',
        'isActive': true,
        'maxReferralsPerUser': 25,
        'createdAt': '2026-08-16T10:00:00.000Z',
        'updatedAt': '2026-08-16T10:00:00.000Z',
      };

      final model = ReferralCampaignModel.fromJson(json);

      expect(model.id, 'cmp_123');
      expect(model.name, 'Festive Referral Campaign');
      expect(model.code, 'FESTIVE2026');
      expect(model.referrerRewardAmount, 300.0);
      expect(model.refereeRewardAmount, 300.0);
      expect(model.minBookingAmount, 1500.0);
      expect(model.city, 'Mumbai');
      expect(model.isActive, true);
      expect(model.maxReferralsPerUser, 25);
    });

    test('ReferralAttributionModel.fromJson parses attribution correctly', () {
      final json = {
        'id': 'attr_456',
        'refereeName': 'John Doe',
        'refereePhone': '+91 98****321',
        'status': 'REWARDED',
        'rewardAmount': 250.0,
        'createdAt': '2026-08-16T12:00:00.000Z',
        'qualifiedAt': '2026-08-16T14:00:00.000Z',
        'rewardedAt': '2026-08-16T14:00:01.000Z',
      };

      final model = ReferralAttributionModel.fromJson(json);

      expect(model.id, 'attr_456');
      expect(model.refereeName, 'John Doe');
      expect(model.refereePhone, '+91 98****321');
      expect(model.status, ReferralStatus.REWARDED);
      expect(model.rewardAmount, 250.0);
    });

    test('ReferralSummaryModel.fromJson parses summary correctly', () {
      final json = {
        'totalInvited': 10,
        'totalRegistered': 8,
        'totalCompleted': 5,
        'totalRewardedCount': 5,
        'totalEarnings': 1250.0,
      };

      final model = ReferralSummaryModel.fromJson(json);

      expect(model.totalInvited, 10);
      expect(model.totalRegistered, 8);
      expect(model.totalCompleted, 5);
      expect(model.totalRewardedCount, 5);
      expect(model.totalEarnings, 1250.0);
    });
  });
}
