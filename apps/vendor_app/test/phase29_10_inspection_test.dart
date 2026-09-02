import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:vendor_app/features/bookings/presentation/pages/vendor_bookings_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/handover_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/pages/return_inspection_page.dart';
import 'package:vendor_app/features/bookings/presentation/providers/vendor_bookings_providers.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  final testBooking = BookingModel(
    id: 'bk_test_01',
    customerId: 'cust_849201',
    vendorId: 'vendor_01',
    carId: 'car_hyundai_creta',
    tripType: 'Outstation',
    pickupLocation: 'Terminal 2, Mumbai Airport',
    startDate: DateTime(2026, 9, 5, 10, 0),
    endDate: DateTime(2026, 9, 8, 18, 0),
    totalFare: 9600.0,
    platformFee: 960.0,
    gstAmount: 1728.0,
    netToVendor: 8640.0,
    status: 'confirmed',
    createdAt: DateTime(2026, 9, 2),
  );

  Widget createTestWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Phase 29.10: Vendor Operations & Inspection Suite', () {
    testWidgets('1. Vendor operations bookings list renders tab bar', (tester) async {
      await tester.pumpWidget(createTestWidget(const VendorBookingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Booking Operations'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Handover Ready'), findsOneWidget);
      expect(find.text('Vehicle Out'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('2. Operational card displays vehicle plate badge and model', (tester) async {
      await tester.pumpWidget(createTestWidget(const VendorBookingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('MH 12 CD 5678'), findsWidgets);
      expect(find.text('Hyundai Creta SX(O) • 2024'), findsWidgets);
    });

    testWidgets('3. Operational card displays customer name and phone badge', (tester) async {
      await tester.pumpWidget(createTestWidget(const VendorBookingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma (+91 98765 43210)'), findsWidgets);
    });

    testWidgets('4. Operational card displays pickup and fare info', (tester) async {
      await tester.pumpWidget(createTestWidget(const VendorBookingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Terminal 2, Mumbai Airport'), findsWidgets);
      expect(find.text('₹9600'), findsWidgets);
    });

    testWidgets('5. "Start Handover Inspection" button is present for confirmed booking', (tester) async {
      await tester.pumpWidget(createTestWidget(const VendorBookingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Start Handover Inspection'), findsWidgets);
    });

    testWidgets('6. Handover inspection page renders 5-step progress header', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Handover Inspection'), findsOneWidget);
      expect(find.text('STEP 1 OF 5: IDENTITY'), findsOneWidget);
      expect(find.text('⚡ 60s Fast Flow'), findsOneWidget);
    });

    testWidgets('7. Handover Step 0 verifies customer and driving license identity checkboxes', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer present in-person with valid Driving License'), findsOneWidget);
      expect(find.text('Vehicle registration plate matches booking manifest'), findsOneWidget);
      expect(find.text('KYC VERIFIED'), findsOneWidget);
    });

    testWidgets('8. Handover navigates to Step 1 (Odometer & Fuel)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 5: ODO & FUEL'), findsOneWidget);
      expect(find.text('Odometer Reading'), findsOneWidget);
      expect(find.text('Fuel Level Indicator'), findsOneWidget);
    });

    testWidgets('9. Handover Step 1 quick bump chips (+10km, +50km, +100km) update odometer', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Go to step 1
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('42390'), findsOneWidget);

      await tester.tap(find.text('+50 km'));
      await tester.pumpAndSettle();

      expect(find.text('42440'), findsOneWidget);
    });

    testWidgets('10. Handover Step 1 one-tap fuel selector updates percentage', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Go to step 1
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.text('75%'));
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsWidgets);
    });

    testWidgets('11. Handover navigates to Step 2 (4-Photo Burst)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 3 OF 5: 4-PHOTOS'), findsOneWidget);
      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Rear'), findsOneWidget);
      expect(find.text('Left Side'), findsOneWidget);
      expect(find.text('Right Side'), findsOneWidget);
      expect(find.text('Captured'), findsNWidgets(4));
    });

    testWidgets('12. Handover navigates to Step 3 (Damage Assessment)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2 -> Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 4 OF 5: DAMAGE'), findsOneWidget);
      expect(find.text('No Pre-Existing Damage'), findsOneWidget);
      expect(find.text('Add Damage Spot'), findsOneWidget);
    });

    testWidgets('13. Handover Step 3 adding a damage spot updates list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Go to step 3
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Damage Spot'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Save Damage Item'), findsOneWidget);
      await tester.tap(find.text('Save Damage Item'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Recorded Damage Spots'), findsOneWidget);
      expect(find.text('Front Bumper • Minor'), findsOneWidget);
    });

    testWidgets('14. Handover navigates to Step 4 (Review & OTP)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Go to step 4
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Continue'), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.text('STEP 5 OF 5: REVIEW'), findsOneWidget);
      expect(find.text('Handover Summary Review'), findsOneWidget);
      expect(find.text('COMPLETE HANDOVER'), findsOneWidget);
    });

    testWidgets('15. Handover offline mode displays connection loss dialog and stores draft', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          const HandoverInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Review step first
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Continue'), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.text('COMPLETE HANDOVER'), findsOneWidget);

      // Toggle offline mode via AppBar icon
      await tester.tap(find.byTooltip('Online Mode'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(find.text('COMPLETE HANDOVER'));
      await tester.pumpAndSettle();

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Handover inspection data has been safely cached on device. It will automatically sync once connection is restored.'), findsOneWidget);
    });

    testWidgets('16. Return inspection page renders 4-step progress header', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Return Inspection'), findsOneWidget);
      expect(find.text('STEP 1 OF 4: ODO & FUEL DELTA'), findsOneWidget);
      expect(find.text('⚡ 60s Fast Flow'), findsOneWidget);
    });

    testWidgets('17. Return Step 0 calculates real-time distance driven', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Handover: 42390, Return: 42681 -> Distance: 291 km
      expect(find.text('Distance Travelled: 291 km'), findsOneWidget);
    });

    testWidgets('18. Return Step 0 validates monotonic odometer constraint', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '41000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Return reading (41000 km) cannot be less than handover reading (42390 km)'), findsOneWidget);
    });

    testWidgets('19. Return Step 0 calculates fuel difference shortfall', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fuel Shortfall: -25% (Refuel charge will apply)'), findsOneWidget);
    });

    testWidgets('20. Return navigates to Step 1 (4-Photos Return)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 4: 4-PHOTOS RETURN'), findsOneWidget);
      expect(find.text('4-Angle Return Exterior Burst'), findsOneWidget);
      expect(find.text('Captured'), findsNWidgets(4));
    });

    testWidgets('21. Return navigates to Step 2 (Before/After Damage Comparison)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 3 OF 4: DAMAGE COMPARISON'), findsOneWidget);
      expect(find.text('Before & After Damage Comparison'), findsOneWidget);
      expect(find.text('HANDOVER (Pre-Trip)'), findsOneWidget);
      expect(find.text('RETURN (Post-Trip)'), findsOneWidget);
      expect(find.text('NEW DAMAGE'), findsOneWidget);
      expect(find.text('New Damage Spot Detected'), findsOneWidget);
    });

    testWidgets('22. Return navigates to Step 3 (Review & Complete)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          const ReturnInspectionPage(bookingId: 'bk_test_01'),
          overrides: [
            singleBookingProvider('bk_test_01').overrideWith((ref) => Future.value(testBooking)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2 -> Step 3
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      expect(find.text('STEP 4 OF 4: REVIEW & COMPLETE'), findsOneWidget);
      expect(find.text('Return Summary & Settlement'), findsOneWidget);
      expect(find.text('COMPLETE RETURN'), findsOneWidget);
    });

    test('23. Provider offlineInspectionDraftsProvider stores and updates drafts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(offlineInspectionDraftsProvider), isEmpty);

      container.read(offlineInspectionDraftsProvider.notifier).update((m) => {
            'bk_01': {
              'type': 'PRE_TRIP',
              'odometer': 42390.0,
            }
          });

      expect(container.read(offlineInspectionDraftsProvider), hasLength(1));
      expect(container.read(offlineInspectionDraftsProvider)['bk_01']?['odometer'], 42390.0);
    });

    test('24. Operations filter tab provider switches active tabs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(vendorBookingsTabProvider), 0);
      container.read(vendorBookingsTabProvider.notifier).state = 1;
      expect(container.read(vendorBookingsTabProvider), 1);
    });
  });
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {}

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  void close({bool force = false}) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
}

final _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  late Encoding encoding;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<HttpClientResponse> get done async => _MockHttpClientResponse();
  @override
  Future flush() async {}
  @override
  String get method => 'GET';
  @override
  Uri get uri => Uri.parse('http://localhost');
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = ""]) {}
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream.value(_transparentPng).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _MockHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => [];
  @override
  X509Certificate? get certificate => null;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];
  @override
  Future<Socket> detachSocket() => throw UnimplementedError();
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) => throw UnimplementedError();
  @override
  bool get persistentConnection => false;
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => ['image/png'];
  @override
  String? value(String name) => name == 'content-type' ? 'image/png' : null;
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void clear() {}
  @override
  void noFolding(String name) {}
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = _transparentPng.length;
  @override
  ContentType? contentType = ContentType('image', 'png');
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = false;
  @override
  int? port;
}
