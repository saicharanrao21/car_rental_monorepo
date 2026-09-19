import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_app/features/auth/presentation/pages/phone_entry_page.dart';

void main() {
  testWidgets('PhoneEntryPage renders Continue with Google and Continue with Apple buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PhoneEntryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify phone entry input and submit button exist
    expect(find.text('Verify Phone'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);

    // Verify social divider
    expect(find.text('OR CONTINUE WITH'), findsOneWidget);

    // Verify Google and Apple buttons exist
    expect(find.byKey(const Key('google_signin_button')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    expect(find.byKey(const Key('apple_signin_button')), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });
}
