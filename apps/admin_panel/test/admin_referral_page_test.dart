import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/referral/data/admin_referral_repository.dart';
import 'package:admin_panel/features/referral/presentation/providers/admin_referral_providers.dart';
import 'package:admin_panel/features/referral/presentation/pages/admin_referral_campaigns_page.dart';

class MockAdminReferralRepository implements AdminReferralRepository {
  @override
  Future<List<ReferralCampaignModel>> getCampaigns() async {
    return [
      ReferralCampaignModel(
        id: 'cmp_1',
        name: 'Standard Referral Program',
        code: 'DEFAULT_GLOBAL',
        referrerRewardAmount: 250,
        refereeRewardAmount: 250,
        minBookingAmount: 1000,
        isActive: true,
        maxReferralsPerUser: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        stats: {
          'total': 12,
          'registered': 8,
          'qualified': 4,
          'rewarded': 4,
          'cancelled': 0,
          'fraudBlocked': 0,
        },
      ),
    ];
  }

  @override
  Future<ReferralCampaignModel> createCampaign(Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<ReferralCampaignModel> updateCampaign(String id, Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<ReferralCampaignModel> toggleCampaign(String id) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('AdminReferralCampaignsPage renders campaigns and performance stats', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminReferralRepositoryProvider.overrideWithValue(MockAdminReferralRepository()),
        ],
        child: const MaterialApp(
          home: AdminReferralCampaignsPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Referral Campaign Management'), findsOneWidget);
    expect(find.text('New Campaign'), findsOneWidget);
    expect(find.text('DEFAULT_GLOBAL'), findsOneWidget);
    expect(find.text('Standard Referral Program'), findsOneWidget);
    expect(find.text('Campaign Performance Stats'), findsOneWidget);
  });
}
