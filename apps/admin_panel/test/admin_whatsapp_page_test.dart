import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/whatsapp/domain/repositories/whatsapp_repository.dart';
import 'package:admin_panel/features/whatsapp/presentation/providers/whatsapp_providers.dart';
import 'package:admin_panel/features/whatsapp/presentation/pages/admin_whatsapp_page.dart';

class TestMockWhatsAppRepo implements WhatsAppRepository {
  bool resendCalled = false;

  @override
  Future<WhatsAppSummaryModel> getSummary() async {
    return const WhatsAppSummaryModel(
      totalMessages: 50,
      sentCount: 10,
      deliveredCount: 30,
      readCount: 8,
      failedCount: 2,
      deliveryRatePercent: 76.0,
    );
  }

  @override
  Future<List<WhatsAppMessageModel>> getMessages({
    WhatsAppMessageStatus? status,
    WhatsAppMessageType? messageType,
    String? search,
    int? skip,
    int? take,
  }) async {
    return [
      WhatsAppMessageModel(
        id: 'msg_1',
        phoneNumber: '+919876543210',
        templateName: 'booking_confirmed',
        messageType: WhatsAppMessageType.bookingConfirmed,
        status: WhatsAppMessageStatus.delivered,
        idempotencyKey: 'key_1',
        bookingId: 'bkg_100',
        createdAt: DateTime.now(),
      ),
      WhatsAppMessageModel(
        id: 'msg_2',
        phoneNumber: '+919876543211',
        templateName: 'booking_cancelled',
        messageType: WhatsAppMessageType.bookingCancelled,
        status: WhatsAppMessageStatus.failed,
        idempotencyKey: 'key_2',
        bookingId: 'bkg_200',
        failureCode: '131026',
        failureReason: 'Undeliverable phone',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<WhatsAppMessageModel> resendMessage(String id) async {
    resendCalled = true;
    return WhatsAppMessageModel(
      id: id,
      phoneNumber: '+919876543211',
      templateName: 'booking_cancelled',
      messageType: WhatsAppMessageType.bookingCancelled,
      status: WhatsAppMessageStatus.sent,
      idempotencyKey: 'key_2_resend',
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  testWidgets('AdminWhatsAppPage renders summary cards, message logs and handles resend', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockRepo = TestMockWhatsAppRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whatsAppRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: AdminWhatsAppPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('WhatsApp Business Communications'), findsOneWidget);

    // Verify KPI Cards
    expect(find.text('Total Messages'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Delivery Rate'), findsOneWidget);
    expect(find.text('76.0%'), findsOneWidget);

    // Verify Message Rows
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(find.text('Booking Confirmed'), findsOneWidget);

    expect(find.text('+919876543211'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('Booking Cancelled'), findsOneWidget);

    // Tap Resend on failed message
    expect(find.text('Resend'), findsOneWidget);
    await tester.tap(find.text('Resend'));
    await tester.pumpAndSettle();

    expect(mockRepo.resendCalled, true);
  });
}
