import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:core/core.dart';
import 'package:admin_panel/core/providers/api_providers.dart';
import 'package:admin_panel/features/integrations/presentation/widgets/runtime_command_centre_widget.dart';

void main() {
  group('RuntimeCommandCentreWidget Tests', () {
    late List<Map<String, dynamic>> recordedRequests;
    late Dio testDio;
    late ApiClient mockApiClient;

    setUp(() {
      recordedRequests = [];
      testDio = Dio();
      testDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            recordedRequests.add({
              'method': options.method,
              'path': options.path,
              'data': options.data,
              'query': options.queryParameters,
            });

            if (options.path == '/admin/integrations/runtime/circuits' && options.method == 'GET') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'razorpay': 'CLOSED',
                  'stripe': 'CLOSED',
                  'cashfree': 'CLOSED',
                  'gupshup_whatsapp': 'HALF_OPEN',
                },
              ));
            }

            if (options.path == '/admin/integrations/runtime/overview' && options.method == 'GET') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'circuits': {
                    'razorpay': 'CLOSED',
                    'stripe': 'CLOSED',
                  },
                  'rollingHealth': {
                    'razorpay': {'successRate': 99.8, 'p50': 150, 'p95': 320, 'p99': 600, 'streak': 0},
                  },
                  'activeIncidentsCount': 1,
                  'recentExecutions': [],
                },
              ));
            }

            if (options.path.contains('/admin/integrations/runtime/circuits/') &&
                options.path.endsWith('/trip')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'message': 'Circuit tripped to OPEN'},
              ));
            }

            if (options.path.contains('/admin/integrations/runtime/circuits/') &&
                options.path.endsWith('/reset')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'message': 'Circuit reset to CLOSED'},
              ));
            }

            if (options.path.contains('/admin/integrations/runtime/simulations/')) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ));
            }

            return handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
          },
        ),
      );

      mockApiClient = ApiClient(tokenStorage: TokenStorage(), dio: testDio);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(mockApiClient),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RuntimeCommandCentreWidget(),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Renders runtime command tower headers, circuits, and pipeline visualizer',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Runtime Control Tower'), findsOneWidget);
      expect(find.text('Provider Fallback & Dynamic Routing Pipeline'), findsOneWidget);
      expect(find.text('Provider Circuit Breakers & Rolling Telemetry'), findsOneWidget);
      expect(find.text('Provider Sandbox & Failover Simulation Runner'), findsOneWidget);
      expect(find.text('RAZORPAY'), findsWidgets);
    });

    testWidgets('2. Trips circuit breaker and triggers POST /circuits/:providerId/trip',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final tripButtons = find.text('Trip Circuit');
      expect(tripButtons, findsWidgets);

      await tester.ensureVisible(tripButtons.first);
      await tester.tap(tripButtons.first);
      await tester.pumpAndSettle();

      final tripRequest = recordedRequests.firstWhere(
        (r) => (r['path'] as String).contains('/trip') && r['method'] == 'POST',
        orElse: () => {},
      );
      expect(tripRequest, isNotEmpty);
    });

    testWidgets('3. Resets circuit breaker and triggers POST /circuits/:providerId/reset',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final resetButtons = find.text('Reset Circuit');
      expect(resetButtons, findsWidgets);

      await tester.ensureVisible(resetButtons.first);
      await tester.tap(resetButtons.first);
      await tester.pumpAndSettle();

      final resetRequest = recordedRequests.firstWhere(
        (r) => (r['path'] as String).contains('/reset') && r['method'] == 'POST',
        orElse: () => {},
      );
      expect(resetRequest, isNotEmpty);
    });

    testWidgets('4. Executes simulation and triggers POST /runtime/simulations/:providerId',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final simButton = find.text('Execute Simulation');
      expect(simButton, findsOneWidget);

      await tester.ensureVisible(simButton);
      await tester.tap(simButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final simRequest = recordedRequests.firstWhere(
        (r) => (r['path'] as String).contains('/runtime/simulations/') && r['method'] == 'POST',
        orElse: () => {},
      );
      expect(simRequest, isNotEmpty);
      expect(find.text('Failover Successfully Executed!'), findsOneWidget);
    });
  });
}
