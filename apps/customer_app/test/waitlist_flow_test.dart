import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/waitlist/presentation/widgets/join_waitlist_sheet.dart';

void main() {
  testWidgets('JoinWaitlistSheet validates required city and handles successful waitlist submission', (tester) async {
    String? submittedCity;
    String? submittedCategory;
    String? submittedNotes;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: JoinWaitlistSheet(
              carId: 'car_hyundai_creta',
              carModelName: 'Hyundai Creta 2024',
              initialCity: 'Bangalore',
              onSubmit: ({
                required String city,
                required DateTime startDate,
                required DateTime endDate,
                String? carCategory,
                String? notes,
              }) async {
                submittedCity = city;
                submittedCategory = carCategory;
                submittedNotes = notes;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial renders
    expect(find.text('Waitlist for Hyundai Creta 2024'), findsOneWidget);
    expect(find.byKey(const Key('waitlist_city_field')), findsOneWidget);
    expect(find.byKey(const Key('waitlist_submit_button')), findsOneWidget);

    // Enter notes
    await tester.enterText(
      find.byKey(const Key('waitlist_notes_field')),
      'Prefer diesel automatic with fastag',
    );
    await tester.pump();

    // Submit form
    await tester.tap(find.byKey(const Key('waitlist_submit_button')));
    await tester.pumpAndSettle();

    // Verify callback parameters
    expect(submittedCity, equals('Bangalore'));
    expect(submittedCategory, equals('SUV'));
    expect(submittedNotes, equals('Prefer diesel automatic with fastag'));

    // Verify success banner appears
    expect(find.byKey(const Key('waitlist_success_banner')), findsOneWidget);
    expect(find.text('You are on the Waitlist!'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('JoinWaitlistSheet displays validation error when city is empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: JoinWaitlistSheet(
              initialCity: '',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clear city text field
    await tester.enterText(find.byKey(const Key('waitlist_city_field')), '');
    await tester.pump();

    // Tap submit
    await tester.tap(find.byKey(const Key('waitlist_submit_button')));
    await tester.pumpAndSettle();

    // Verify validation message
    expect(find.text('Please enter a city'), findsOneWidget);
    expect(find.byKey(const Key('waitlist_success_banner')), findsNothing);
  });
}
