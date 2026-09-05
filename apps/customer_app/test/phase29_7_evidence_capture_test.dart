import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:customer_app/core/providers/session_provider.dart';
import 'package:customer_app/features/profile/presentation/pages/profile_page.dart';
import 'package:customer_app/features/profile/presentation/pages/kyc_upload_page.dart';
import 'package:customer_app/features/wallet/presentation/pages/wallet_page.dart';
import 'package:customer_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:customer_app/features/wallet/data/wallet_repository.dart';
import 'package:customer_app/features/loyalty/presentation/pages/loyalty_page.dart';
import 'package:customer_app/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:customer_app/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_app/features/referral/presentation/pages/referral_page.dart';
import 'package:customer_app/features/referral/presentation/providers/referral_providers.dart';
import 'package:customer_app/features/referral/data/referral_repository.dart';
import 'package:customer_app/features/support/presentation/pages/support_center_page.dart';
import 'package:customer_app/features/support/presentation/providers/support_providers.dart';
import 'package:customer_app/features/support/domain/repositories/support_repository.dart';
import 'package:customer_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:customer_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:customer_app/features/notifications/domain/repositories/notifications_repository.dart';
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

class MockLoyaltyRepo implements LoyaltyRepository {
  final LoyaltyAccountModel account;
  final List<LoyaltyTransactionModel> transactions;

  MockLoyaltyRepo({required this.account, required this.transactions});

  @override
  Future<LoyaltyAccountModel> getLoyaltyAccount() async => account;

  @override
  Future<List<LoyaltyTransactionModel>> getLoyaltyTransactions({int page = 1, int limit = 20}) async => transactions;

  @override
  Future<List<LoyaltyTierModel>> getLoyaltyTiers() async => [];

  @override
  Future<Map<String, dynamic>> redeemPointsToWallet(int points, {String? idempotencyKey}) async {
    return {'success': true, 'redeemedPoints': points, 'walletCreditAmount': (points / 2).floor()};
  }
}

class MockReferralRepo implements ReferralRepository {
  @override
  Future<Map<String, dynamic>> getMyReferralCode() async {
    return {
      'referralCode': 'DGAARAV1',
      'shareUrl': 'https://drivego.in/invite?code=DGAARAV1',
      'referrerReward': 250,
      'refereeDiscount': 250,
      'minBookingAmount': 1000,
    };
  }

  @override
  Future<Map<String, dynamic>> getReferralHistory() async {
    return {
      'summary': {
        'totalInvited': 5,
        'totalRegistered': 4,
        'totalCompleted': 2,
        'totalRewardedCount': 2,
        'totalEarnings': 500.0,
      },
      'referrals': [
        {
          'id': 'ref_1',
          'refereeName': 'Pooja Reddy',
          'refereePhone': '+91 98765 43210',
          'status': 'REWARDED',
          'rewardAmount': 250.0,
          'createdAt': '2026-08-20T10:00:00.000Z',
        },
        {
          'id': 'ref_2',
          'refereeName': 'Vikram Singh',
          'refereePhone': '+91 91234 56789',
          'status': 'REWARDED',
          'rewardAmount': 250.0,
          'createdAt': '2026-08-22T14:30:00.000Z',
        },
        {
          'id': 'ref_3',
          'refereeName': 'Neha Sharma',
          'refereePhone': '+91 99887 76655',
          'status': 'REGISTERED',
          'rewardAmount': 250.0,
          'createdAt': '2026-08-28T09:15:00.000Z',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getRefereeEligibility() async {
    return {'eligible': true, 'discountAmount': 250.0, 'minBookingAmount': 1000.0};
  }

  @override
  Future<Map<String, dynamic>> applyReferralCode(String code, {String? city}) async {
    return {'success': true, 'message': 'Referral code applied!', 'discountAmount': 250.0, 'minBookingAmount': 1000.0};
  }
}

class MockSupportRepo implements SupportRepository {
  @override
  Future<SupportTicketModel> createTicket({
    required TicketCategory category,
    TicketPriority priority = TicketPriority.NORMAL,
    required String subject,
    required String description,
    String? bookingId,
    List<String>? attachments,
  }) async {
    return SupportTicketModel(
      id: 'tick_1',
      ticketNumber: 'TICK-9082',
      customerId: 'user_test_1',
      category: category,
      priority: priority,
      status: TicketStatus.OPEN,
      subject: subject,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );
  }

  @override
  Future<List<SupportTicketModel>> getMyTickets() async {
    return [
      SupportTicketModel(
        id: 'tick_101',
        ticketNumber: 'TICK-10492',
        customerId: 'user_test_1',
        category: TicketCategory.PAYMENT,
        priority: TicketPriority.HIGH,
        status: TicketStatus.OPEN,
        subject: 'Fastag Toll Recharge Reconciliation',
        description: 'Need invoice breakdown for Fastag toll charges on trip BK-8902.',
        createdAt: DateTime(2026, 8, 29, 14, 30),
        updatedAt: DateTime(2026, 8, 29, 14, 30),
        messages: [],
      ),
      SupportTicketModel(
        id: 'tick_102',
        ticketNumber: 'TICK-10381',
        customerId: 'user_test_1',
        category: TicketCategory.VEHICLE,
        priority: TicketPriority.NORMAL,
        status: TicketStatus.RESOLVED,
        subject: 'Doorstep Pickup Location Adjustment',
        description: 'Successfully coordinated vehicle pickup handover at Terminal 2.',
        createdAt: DateTime(2026, 8, 20, 11, 0),
        updatedAt: DateTime(2026, 8, 21, 10, 0),
        messages: [],
      ),
    ];
  }

  @override
  Future<SupportTicketModel> getTicketById(String ticketId) async {
    return SupportTicketModel(
      id: ticketId,
      ticketNumber: 'TICK-10492',
      customerId: 'user_test_1',
      category: TicketCategory.PAYMENT,
      priority: TicketPriority.HIGH,
      status: TicketStatus.OPEN,
      subject: 'Fastag Toll Recharge Reconciliation',
      description: 'Need invoice breakdown for Fastag toll charges on trip BK-8902.',
      createdAt: DateTime(2026, 8, 29, 14, 30),
      updatedAt: DateTime(2026, 8, 29, 14, 30),
      messages: [],
    );
  }

  @override
  Future<TicketMessageModel> replyTicket({
    required String ticketId,
    required String message,
    List<String>? attachments,
  }) async {
    return TicketMessageModel(
      id: 'msg_1',
      ticketId: ticketId,
      senderId: 'user_test_1',
      senderRole: 'CUSTOMER',
      message: message,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<SupportTicketModel> closeTicket(String ticketId) async {
    return getTicketById(ticketId);
  }

  @override
  Future<SupportTicketModel> reopenTicket({
    required String ticketId,
    required String reason,
  }) async {
    return getTicketById(ticketId);
  }
}

class MockNotificationsRepo implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    return [
      NotificationModel(
        id: 'notif_1',
        title: 'Booking Confirmed (BK-8902)',
        body: 'Your Hyundai Creta AT has been assigned and cleaned for delivery in Indiranagar.',
        type: 'BOOKING_CONFIRMED',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      NotificationModel(
        id: 'notif_2',
        title: 'Referral Bonus Credited (+₹250)',
        body: 'Pooja Reddy completed her first trip. ₹250 added to your DriveGo Wallet.',
        type: 'WALLET_CREDIT',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        id: 'notif_3',
        title: 'Rewards Tier Upgrade: Gold Club',
        body: 'Congratulations! You unlocked 1.50x points multiplier and priority roadside support.',
        type: 'LOYALTY_UPGRADE',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  Future<void> markAllRead(String userId) async {}

  @override
  Future<void> markAsRead(String notificationId) async {}
}


class MockWalletRepo implements WalletRepository {
  @override
  Future<WalletModel> getWallet() async {
    return WalletModel(
      id: 'wlt_test_1',
      userId: 'user_test_1',
      currency: 'INR',
      availableBalance: 4750.0,
      lockedBalance: 0.0,
      realBalance: 3500.0,
      promoBalance: 1250.0,
      status: WalletStatus.ACTIVE,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<WalletLedgerEntryModel>> getTransactions({int page = 1, int limit = 20}) async {
    return [
      WalletLedgerEntryModel(
        id: 'tx_1',
        walletId: 'wlt_test_1',
        type: LedgerEntryType.CUSTOMER_DEPOSIT,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.REAL_MONEY,
        amount: 2000.0,
        balanceBefore: 2750.0,
        balanceAfter: 4750.0,
        referenceType: 'PAYMENT',
        referenceId: 'pay_9821734',
        idempotencyKey: 'idemp_dep_1',
        description: 'Instant Wallet Deposit via UPI / Razorpay',
        createdAt: DateTime(2026, 8, 30, 16, 45),
      ),
      WalletLedgerEntryModel(
        id: 'tx_2',
        walletId: 'wlt_test_1',
        type: LedgerEntryType.REFERRAL_REWARD,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.PROMOTIONAL,
        amount: 250.0,
        balanceBefore: 2500.0,
        balanceAfter: 2750.0,
        referenceType: 'REFERRAL',
        referenceId: 'ref_pooja',
        idempotencyKey: 'idemp_ref_1',
        description: 'Referral Bonus: Pooja Reddy First Booking',
        createdAt: DateTime(2026, 8, 28, 12, 10),
      ),
      WalletLedgerEntryModel(
        id: 'tx_3',
        walletId: 'wlt_test_1',
        type: LedgerEntryType.CHECKOUT_DEBIT,
        direction: LedgerDirection.DEBIT,
        bucket: WalletBucketType.REAL_MONEY,
        amount: 1850.0,
        balanceBefore: 4350.0,
        balanceAfter: 2500.0,
        referenceType: 'BOOKING',
        referenceId: 'BK-8902',
        idempotencyKey: 'idemp_bk_1',
        description: 'Trip Booking Payment — Hyundai Creta AT',
        createdAt: DateTime(2026, 8, 24, 9, 30),
      ),
      WalletLedgerEntryModel(
        id: 'tx_4',
        walletId: 'wlt_test_1',
        type: LedgerEntryType.LOYALTY_CONVERSION,
        direction: LedgerDirection.CREDIT,
        bucket: WalletBucketType.PROMOTIONAL,
        amount: 500.0,
        balanceBefore: 3850.0,
        balanceAfter: 4350.0,
        referenceType: 'LOYALTY',
        referenceId: 'loy_1000pts',
        idempotencyKey: 'idemp_loy_1',
        description: 'Redeemed 1,000 Rewards Club Points',
        createdAt: DateTime(2026, 8, 15, 18, 0),
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> createDepositOrder(double amount) async {
    return {'orderId': 'order_dep_123', 'amount': amount, 'currency': 'INR', 'keyId': 'rzp_test_mock', 'isMock': true};
  }

  @override
  Future<Map<String, dynamic>> verifyDeposit({required String orderId, required String paymentId, required String signature}) async {
    return {'success': true, 'message': 'Wallet recharged successfully!'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('razorpay_flutter'),
      (MethodCall methodCall) async => null,
    );
    DDSTypography.useSystemFallbackInTests = true;
  });

  tearDownAll(() {
    DDSTypography.useSystemFallbackInTests = false;
  });

  const testUser = UserModel(
    id: 'user_test_1',
    phone: '+91 98765 43210',
    name: 'Aarav Sharma',
    email: 'aarav.sharma@drivego.in',
    role: 'CUSTOMER',
    banned: false,
  );

  final testLoyalty = LoyaltyAccountModel(
    id: 'loy_test_1',
    userId: 'user_test_1',
    tierCode: LoyaltyTierCode.gold,
    tierName: 'Gold',
    pointsMultiplier: 1.5,
    pointsBalance: 1450,
    lifetimePoints: 3200,
    walletEquivalent: 725,
    currentTier: const LoyaltyTierModel(
      id: 'tier_gold',
      code: LoyaltyTierCode.gold,
      name: 'Gold',
      minPointsRequired: 2000,
      pointsMultiplier: 1.5,
      prioritySupport: true,
    ),
    nextTier: const LoyaltyNextTierModel(
      code: LoyaltyTierCode.platinum,
      name: 'Platinum',
      minPointsRequired: 5000,
      pointsMultiplier: 2.0,
      pointsToNextTier: 1800,
      progressPercent: 40.0,
    ),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testTransactions = [
    LoyaltyTransactionModel(
      id: 'ltx_1',
      type: LoyaltyTransactionType.tripCompletionEarned,
      points: 350,
      balanceBefore: 1100,
      balanceAfter: 1450,
      referenceType: 'BOOKING',
      referenceId: 'BK-8902',
      idempotencyKey: 'idemp_1',
      description: 'Earned 350 points for 4-day Creta AT rental (1.5x Gold perk)',
      createdAt: DateTime(2026, 8, 28, 14, 0),
    ),
    LoyaltyTransactionModel(
      id: 'ltx_2',
      type: LoyaltyTransactionType.tierUpgradeBonus,
      points: 200,
      balanceBefore: 900,
      balanceAfter: 1100,
      referenceType: 'TIER',
      referenceId: 'gold_upgrade',
      idempotencyKey: 'idemp_2',
      description: 'Gold Tier Upgrade Welcome Bonus',
      createdAt: DateTime(2026, 8, 15, 10, 0),
    ),
  ];

  Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String path) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });
  }

  Widget createFramedSubject({
    required Widget child,
    required GlobalKey key,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => MockSessionNotifier(testUser)),
        walletRepositoryProvider.overrideWithValue(MockWalletRepo()),
        loyaltyRepositoryProvider.overrideWithValue(MockLoyaltyRepo(account: testLoyalty, transactions: testTransactions)),
        referralRepositoryProvider.overrideWithValue(MockReferralRepo()),
        supportRepositoryProvider.overrideWithValue(MockSupportRepo()),
        notificationsRepositoryProvider.overrideWithValue(MockNotificationsRepo()),
        kycStatusProvider.overrideWith((ref) async => {
              'status': 'VERIFIED',
              'kyc': {
                'licenceNumber': 'DL1420110012345',
                'expiryDate': '2032-12-31T00:00:00.000Z',
                'licenceFrontUrl': 'https://storage.drivego.in/dl_front.jpg',
                'licenceBackUrl': 'https://storage.drivego.in/dl_back.jpg',
              }
            }),
        wishlistIdsProvider.overrideWith((ref) {
          final notifier = WishlistIdsNotifier(ref);
          notifier.setInitial({'car_1', 'car_2', 'car_3'});
          return notifier;
        }),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: DDSColors.primaryBlue),
          scaffoldBackgroundColor: DDSColors.bgCanvas,
        ),
        home: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 390,
            height: 844,
            child: child,
          ),
        ),
      ),
    );
  }

  group('DriveGo Phase 29.7 Visual Evidence Capture (12 Screens)', () {
    const evidenceDir = 'd:/Flutter/car_rental_monorepo/docs/evidence/phase29-7-profile-kyc-wallet-loyalty';

    testWidgets('01_profile_overview.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const ProfilePage()));
      await saveScreenshot(tester, key, '$evidenceDir/01_profile_overview.png');
    });

    testWidgets('02_profile_account_status.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const ProfilePage()));
      await saveScreenshot(tester, key, '$evidenceDir/02_profile_account_status.png');
    });

    testWidgets('03_kyc_status.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const KycUploadPage()));
      await saveScreenshot(tester, key, '$evidenceDir/03_kyc_status.png');
    });

    testWidgets('04_kyc_flow.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(
        createFramedSubject(
          key: key,
          overrides: [
            kycStatusProvider.overrideWith((ref) async => {'status': 'NONE', 'kyc': null}),
          ],
          child: const KycUploadPage(),
        ),
      );
      await saveScreenshot(tester, key, '$evidenceDir/04_kyc_flow.png');
    });

    testWidgets('05_wallet_overview.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const WalletPage()));
      await saveScreenshot(tester, key, '$evidenceDir/05_wallet_overview.png');
    });

    testWidgets('06_wallet_transactions.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const WalletPage()));
      await saveScreenshot(tester, key, '$evidenceDir/06_wallet_transactions.png');
    });

    testWidgets('07_promotional_balance.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const WalletPage()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('+ Add Money'));
      await tester.pump(const Duration(milliseconds: 100));
      await saveScreenshot(tester, key, '$evidenceDir/07_promotional_balance.png');
    });

    testWidgets('08_referrals.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const ReferralPage()));
      await saveScreenshot(tester, key, '$evidenceDir/08_referrals.png');
    });

    testWidgets('09_loyalty.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const LoyaltyPage()));
      await saveScreenshot(tester, key, '$evidenceDir/09_loyalty.png');
    });

    testWidgets('10_notification_preferences.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const NotificationsPage()));
      await saveScreenshot(tester, key, '$evidenceDir/10_notification_preferences.png');
    });

    testWidgets('11_security_settings.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const ProfilePage()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump(const Duration(milliseconds: 100));
      await saveScreenshot(tester, key, '$evidenceDir/11_security_settings.png');
    });

    testWidgets('12_support_entry.png', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      final key = GlobalKey();
      await tester.pumpWidget(createFramedSubject(key: key, child: const SupportCenterPage()));
      await saveScreenshot(tester, key, '$evidenceDir/12_support_entry.png');
    });
  });
}
