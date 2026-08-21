import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/features/profile/presentation/pages/profile_page.dart';
import 'package:customer_app/features/profile/presentation/pages/kyc_upload_page.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:customer_app/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:customer_app/features/referral/presentation/providers/referral_providers.dart';
import 'package:customer_app/features/wishlist/wishlist_providers.dart';

class MockSessionNotifier extends SessionNotifier {
  final UserModel? initialUser;
  MockSessionNotifier(this.initialUser);

  @override
  AuthState build() {
    if (initialUser != null) {
      return AuthState.authenticated(initialUser!);
    }
    return AuthState.unauthenticated();
  }
}

void main() {
  const testUser = UserModel(
    id: 'user_test_1',
    phone: '+919876543210',
    name: 'Aarav Sharma',
    email: 'aarav.sharma@example.com',
    role: 'CUSTOMER',
    banned: false,
  );

  final testWallet = WalletModel(
    id: 'wlt_test_1',
    userId: 'user_test_1',
    currency: 'INR',
    availableBalance: 3500.0,
    lockedBalance: 0.0,
    realBalance: 3000.0,
    promoBalance: 500.0,
    status: WalletStatus.ACTIVE,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testLoyalty = LoyaltyAccountModel(
    id: 'loy_test_1',
    userId: 'user_test_1',
    tierCode: LoyaltyTierCode.silver,
    tierName: 'Silver',
    pointsMultiplier: 1.25,
    pointsBalance: 450,
    lifetimePoints: 1200,
    walletEquivalent: 112,
    currentTier: const LoyaltyTierModel(
      id: 'tier_silver',
      code: LoyaltyTierCode.silver,
      name: 'Silver',
      minPointsRequired: 1000,
      pointsMultiplier: 1.25,
    ),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget createSubject({
    UserModel? user,
    Map<String, dynamic>? kycData,
    WalletModel? wallet,
    LoyaltyAccountModel? loyalty,
    Map<String, dynamic>? referral,
    Set<String> wishlistedIds = const {'car_1', 'car_2'},
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        sessionProvider.overrideWith(() => MockSessionNotifier(user)),
        kycStatusProvider.overrideWith((ref) async => kycData ?? {'status': 'VERIFIED'}),
        customerWalletProvider.overrideWith((ref) async => wallet ?? testWallet),
        loyaltyAccountProvider.overrideWith((ref) async => loyalty ?? testLoyalty),
        myReferralCodeProvider.overrideWith((ref) async => referral ?? {'code': 'DGAARAV1'}),
        wishlistIdsProvider.overrideWith((ref) {
          final notifier = WishlistIdsNotifier(ref);
          notifier.setInitial(wishlistedIds);
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: ProfilePage(),
      ),
    );
  }

  group('ProfilePage Modernization & Wiring Tests (Phase 17.2)', () {
    testWidgets('1. Renders authenticated user details, initials avatar, and phone', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('aarav.sharma@example.com'), findsOneWidget);
      expect(find.text('AS'), findsOneWidget); // Initials
      expect(find.text('Verified Driver'), findsOneWidget);
    });

    testWidgets('2. Renders unauthenticated fallback when user is null', (tester) async {
      await tester.pumpWidget(createSubject(user: null));
      await tester.pumpAndSettle();

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('3. Displays dynamic KYC status badges correctly', (tester) async {
      // PENDING KYC
      await tester.pumpWidget(createSubject(user: testUser, kycData: {'status': 'PENDING'}));
      await tester.pumpAndSettle();
      expect(find.text('KYC Under Review'), findsOneWidget);

      // NONE / Unverified
      await tester.pumpWidget(createSubject(user: testUser, kycData: {'status': 'NONE'}));
      await tester.pumpAndSettle();
      expect(find.text('Verify Driving Licence'), findsOneWidget);

      // REJECTED
      await tester.pumpWidget(createSubject(user: testUser, kycData: {'status': 'REJECTED'}));
      await tester.pumpAndSettle();
      expect(find.text('KYC Rejected'), findsOneWidget);
    });

    testWidgets('4. Displays real quick stats bar for Wallet, Rewards, and Referral', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      expect(find.text('₹3500'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('450 pts'), findsOneWidget);
      expect(find.text('Club Rewards'), findsOneWidget);
      expect(find.text('₹250 Off'), findsOneWidget);
      expect(find.text('Refer & Earn'), findsNWidgets(2)); // Stats card + Menu tile
    });

    testWidgets('5. Renders menu tiles with subtitles and wishlist count', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser, wishlistedIds: {'car_1', 'car_2', 'car_3'}));
      await tester.pumpAndSettle();

      expect(find.text('Driving Licence (KYC)'), findsOneWidget);
      expect(find.text('DriveGo Wallet & Credits'), findsOneWidget);
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Saved Cars (Wishlist)'), findsOneWidget);
      expect(find.text('3 cars saved'), findsOneWidget);
      expect(find.text('Help & Support Center'), findsOneWidget);
      expect(find.text('Emergency Roadside SOS'), findsOneWidget);
      expect(find.text('About DriveGo'), findsOneWidget);
    });

    testWidgets('6. Opens Edit Profile bottom sheet with form pre-populated', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsOneWidget);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNWidgets(2)); // Card + Form field
      expect(find.text('aarav.sharma@example.com'), findsNWidgets(2));
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('7. Edit Profile form validates required name and email format', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Clear name and enter invalid email
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), 'notanemail');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('8. About DriveGo dialog opens with version and details', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      final aboutFinder = find.text('About DriveGo');
      await tester.ensureVisible(aboutFinder);
      await tester.tap(aboutFinder);
      await tester.pumpAndSettle();

      expect(find.text('DriveGo Self-Drive & Chauffeur'), findsOneWidget);
      expect(find.text('Version 1.0.0 (Release Candidate)'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('DriveGo Self-Drive & Chauffeur'), findsNothing);
    });

    testWidgets('9. Sign Out triggers confirmation dialog', (tester) async {
      await tester.pumpWidget(createSubject(user: testUser));
      await tester.pumpAndSettle();

      final signOutFinder = find.text('Sign Out');
      await tester.ensureVisible(signOutFinder);
      await tester.tap(signOutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsNWidgets(2)); // Title & button
      expect(find.text('Are you sure you want to sign out from DriveGo?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to sign out from DriveGo?'), findsNothing);
    });

    testWidgets('10. Provider errors render non-financial Unavailable states and not fake zero data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sessionProvider.overrideWith(() => MockSessionNotifier(testUser)),
            kycStatusProvider.overrideWith((ref) => Future.error(Exception('Network error'))),
            customerWalletProvider.overrideWith((ref) => Future.error(Exception('Wallet service down'))),
            loyaltyAccountProvider.overrideWith((ref) => Future.error(Exception('Loyalty service down'))),
            myReferralCodeProvider.overrideWith((ref) => Future.error(Exception('Referral service down'))),
            wishlistIdsProvider.overrideWith((ref) {
              final notifier = WishlistIdsNotifier(ref);
              notifier.setInitial(const {});
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no misleading fake business data is rendered on error
      expect(find.text('₹0'), findsNothing);
      expect(find.text('0 pts'), findsNothing);

      // Verify explicit Unavailable indicators are rendered for quick stats
      expect(find.text('Unavailable'), findsNWidgets(3)); // Wallet, Loyalty, Referral
      expect(find.text('Status Unavailable'), findsOneWidget); // KYC badge
      expect(find.text('Status unavailable'), findsOneWidget); // Driving Licence subtitle
    });
  });
}
