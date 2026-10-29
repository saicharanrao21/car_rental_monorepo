import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:admin_panel/features/integrations/data/repositories/admin_integrations_repository.dart';
import 'package:admin_panel/features/integrations/presentation/widgets/notification_rules_centre_widget.dart';

class MockNotificationRulesRepo extends AdminIntegrationsRepository {
  MockNotificationRulesRepo() : super(ApiClient(tokenStorage: TokenStorage(), dio: Dio()));

  final List<Map<String, dynamic>> rules = [
    {
      'id': 'rule_booking_confirmed',
      'eventType': 'BOOKING_CONFIRMED',
      'label': 'Booking Confirmed',
      'category': 'BOOKINGS',
      'recipientRole': 'CUSTOMER',
      'channels': {'whatsapp': true, 'push': true, 'email': true, 'sms': false},
      'allowQuietHoursBypass': false,
      'isEnabled': true,
      'templateKey': 'BOOKING_CONFIRMATION',
      'description': 'Dispatched immediately when payment succeeds and vehicle is locked.',
      'priority': 1,
    },
    {
      'id': 'rule_payment_failed',
      'eventType': 'PAYMENT_FAILED',
      'label': 'Payment Authorization Failed',
      'category': 'PAYMENTS',
      'recipientRole': 'CUSTOMER',
      'channels': {'whatsapp': false, 'push': true, 'email': true, 'sms': true},
      'allowQuietHoursBypass': true,
      'isEnabled': true,
      'templateKey': 'PAYMENT_FAILED',
      'description': 'High-urgency alert notifying customer of payment gateway decline.',
      'priority': 2,
    },
    {
      'id': 'rule_trip_start_otp',
      'eventType': 'TRIP_START_OTP',
      'label': 'Trip Start OTP Challenge',
      'category': 'TRIP',
      'recipientRole': 'CUSTOMER',
      'channels': {'whatsapp': true, 'push': true, 'email': false, 'sms': true},
      'allowQuietHoursBypass': true,
      'isEnabled': true,
      'templateKey': 'TRIP_START_OTP',
      'description': 'One-time passcode required for vehicle handover and trip start.',
      'priority': 1,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getNotificationRules() async {
    return rules;
  }

  @override
  Future<Map<String, dynamic>> upsertNotificationRule(Map<String, dynamic> rule) async {
    final idx = rules.indexWhere((r) => r['id'] == rule['id']);
    if (idx >= 0) {
      rules[idx] = Map<String, dynamic>.from(rule);
    } else {
      rules.add(Map<String, dynamic>.from(rule));
    }
    return rule;
  }

  @override
  Future<Map<String, dynamic>> toggleNotificationRule(String id, bool isEnabled) async {
    final r = rules.firstWhere((item) => item['id'] == id);
    r['isEnabled'] = isEnabled;
    return r;
  }

  @override
  Future<Map<String, dynamic>> simulateNotificationRule(
    String eventType, {
    String? recipientRole,
  }) async {
    final rule = rules.firstWhere(
      (r) => r['eventType'] == eventType,
      orElse: () => rules.first,
    );

    final resolved = <String>[];
    final channels = rule['channels'] as Map<String, dynamic>? ?? {};
    if (channels['whatsapp'] == true) resolved.add('WHATSAPP');
    if (channels['push'] == true) resolved.add('PUSH');
    if (channels['email'] == true) resolved.add('EMAIL');
    if (channels['sms'] == true) resolved.add('SMS');

    return {
      'simulatedAt': DateTime.now().toIso8601String(),
      'eventType': eventType,
      'recipientRole': recipientRole ?? rule['recipientRole'],
      'activeRule': rule,
      'resolvedChannels': resolved,
      'quietHoursStatus': {
        'currentHour': 14,
        'isInQuietHours': false,
        'bypassActive': rule['allowQuietHoursBypass'],
        'allowedToDispatch': true,
      },
      'deliverySimulation': resolved.map((c) {
        return {
          'channel': c,
          'target': recipientRole == 'CUSTOMER' ? '+919876543210' : 'ops@drivego.in',
          'preview': 'Simulated template dispatch for $eventType over $c gateway.',
        };
      }).toList(),
    };
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        adminIntegrationsRepositoryProvider.overrideWithValue(MockNotificationRulesRepo()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: NotificationRulesCentreWidget(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Renders Event & Notification Rules Centre with title, KPIs, and table', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Event & Notification Rules Centre'), findsOneWidget);
    expect(find.text('Canonical Lifecycle Events'), findsOneWidget);
    expect(find.text('WhatsApp Gateway'), findsOneWidget);
    expect(find.text('Quiet Hours Bypass'), findsOneWidget);

    expect(find.text('Booking Confirmed'), findsOneWidget);
    expect(find.text('Payment Authorization Failed'), findsOneWidget);
    expect(find.text('Trip Start OTP Challenge'), findsOneWidget);
    expect(find.text('Bypass Allowed'), findsNWidgets(2));
    expect(find.text('Respects 9PM-8AM'), findsOneWidget);
  });

  testWidgets('Opens Edit Rule Dialog and displays permitted delivery gateways', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final editBtn = find.byTooltip('Edit Rule Channels & Policy').first;
    await tester.ensureVisible(editBtn);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('Edit Rule: Booking Confirmed'), findsOneWidget);
    expect(find.text('Permitted Delivery Gateways:'), findsOneWidget);
    expect(find.text('WhatsApp Cloud API (Primary Conversational)'), findsOneWidget);
    expect(find.text('Allow Quiet Hours Bypass (21:00 - 08:00)'), findsOneWidget);
    expect(find.text('Save Rule'), findsOneWidget);
  });

  testWidgets('Opens Dispatch Simulator Dialog and displays pre-flight execution check', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Click on simulate button for first rule
    final simBtn = find.text('Simulate').first;
    await tester.ensureVisible(simBtn);
    await tester.tap(simBtn);
    await tester.pumpAndSettle();

    expect(find.text('Event Dispatch Simulator & Pre-Flight Check'), findsOneWidget);
    expect(find.textContaining('DISPATCH ALLOWED'), findsOneWidget);
    expect(find.text('Resolved Channels for Event:'), findsOneWidget);
    expect(find.text('Simulated Channel Payloads:'), findsOneWidget);
  });
}
