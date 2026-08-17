import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/referral/data/referral_repository.dart';
import 'package:customer_app/features/referral/presentation/providers/referral_providers.dart';
import 'package:customer_app/features/referral/presentation/pages/referral_page.dart';

class MockReferralRepository implements ReferralRepository {
  @override
  Future<Map<String, dynamic>> getMyReferralCode() async {
    return {
      'referralCode': 'DGALICE1',
      'shareUrl': 'https://drivego.in/invite?code=DGALICE1',
      'referrerReward': 250,
      'refereeDiscount': 250,
      'minBookingAmount': 1000,
    };
  }

  @override
  Future<Map<String, dynamic>> getReferralHistory() async {
    return {
      'summary': {
        'totalInvited': 3,
        'totalRegistered': 3,
        'totalCompleted': 1,
        'totalRewardedCount': 1,
        'totalEarnings': 250.0,
      },
      'referrals': [
        {
          'id': 'attr_1',
          'refereeName': 'Bob',
          'refereePhone': '+91 98****321',
          'status': 'REWARDED',
          'rewardAmount': 250.0,
          'createdAt': '2026-08-16T10:00:00.000Z',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getRefereeEligibility() async {
    return {
      'eligible': true,
      'discountAmount': 250.0,
      'minBookingAmount': 1000.0,
    };
  }

  @override
  Future<Map<String, dynamic>> applyReferralCode(String code, {String? city}) async {
    return {
      'success': true,
      'message': 'Referral code applied!',
      'discountAmount': 250.0,
      'minBookingAmount': 1000.0,
    };
  }
}

void main() {
  testWidgets('ReferralPage renders referral code and summary statistics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralRepositoryProvider.overrideWithValue(MockReferralRepository()),
        ],
        child: const MaterialApp(
          home: ReferralPage(),
        ),
      ),
    );

    // Initial loading
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Refer & Earn'), findsOneWidget);
    expect(find.text('Invite Friends, Earn ₹250'), findsOneWidget);
    expect(find.text('DGALICE1'), findsOneWidget);
    expect(find.text('Have a friend\'s referral code?'), findsOneWidget);
  });
}
