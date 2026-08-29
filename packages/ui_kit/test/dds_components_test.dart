import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithMaterial(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('DriveGo Design System (DDS) — Component Test Suite', () {
    testWidgets('DriveGoButton renders text and triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoButton(
          text: 'Book Car',
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.text('Book Car'), findsOneWidget);
      await tester.tap(find.text('Book Car'));
      expect(tapped, true);
    });

    testWidgets('DriveGoButton renders loading spinner when isLoading=true', (tester) async {
      await tester.pumpWidget(wrapWithMaterial(
        const DriveGoButton(
          text: 'Submit',
          isLoading: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('DriveGoTextField renders label, hint and accepts input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoTextField(
          label: 'Full Name',
          hint: 'Enter your name',
          controller: controller,
        ),
      ));

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Enter your name'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Rajesh Sharma');
      expect(controller.text, 'Rajesh Sharma');
    });

    testWidgets('DriveGoCard renders child and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoCard(
          onTap: () => tapped = true,
          child: const Text('Card Content'),
        ),
      ));

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(tapped, true);
    });

    testWidgets('DriveGoStatusBadge displays correct text and variants', (tester) async {
      await tester.pumpWidget(wrapWithMaterial(
        const Column(
          children: [
            DriveGoStatusBadge(label: 'CONFIRMED'),
            DriveGoStatusBadge(label: 'PENDING'),
            DriveGoStatusBadge(label: 'CANCELLED'),
            DriveGoStatusBadge(label: 'SPONSORED'),
          ],
        ),
      ));

      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('SPONSORED'), findsOneWidget);
    });

    testWidgets('DriveGoPriceTag formats currency and renders strikethrough & suffix', (tester) async {
      await tester.pumpWidget(wrapWithMaterial(
        const DriveGoPriceTag(
          amount: 2500,
          originalAmount: 3000,
          suffix: '/day',
        ),
      ));

      expect(find.text('₹2,500'), findsOneWidget);
      expect(find.text('₹3,000'), findsOneWidget);
      expect(find.text('/day'), findsOneWidget);
    });

    testWidgets('DriveGoLoadingState renders fullPage and shimmer variants', (tester) async {
      await tester.pumpWidget(wrapWithMaterial(
        const DriveGoLoadingState(
          variant: DriveGoLoadingVariant.fullPage,
          message: 'Loading Vehicles...',
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Vehicles...'), findsOneWidget);
    });

    testWidgets('DriveGoEmptyState renders title, subtitle, and actions', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoEmptyState(
          icon: Icons.car_rental,
          title: 'No Cars Found',
          subtitle: 'Try adjusting your filters',
          actionText: 'Clear Filters',
          onActionPressed: () => actionTapped = true,
        ),
      ));

      expect(find.text('No Cars Found'), findsOneWidget);
      expect(find.text('Try adjusting your filters'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      expect(actionTapped, true);
    });

    testWidgets('DriveGoErrorState renders title, message, and retry button', (tester) async {
      bool retried = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoErrorState(
          message: 'Network connection timeout',
          onRetry: () => retried = true,
        ),
      ));

      expect(find.text('Unable to Load Content'), findsOneWidget);
      expect(find.text('Network connection timeout'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, true);
    });

    testWidgets('DriveGoChip handles selection and taps', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoChip(
          label: 'SUV',
          isSelected: true,
          showCheckmark: true,
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('SUV'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('SUV'));
      expect(tapped, true);
    });

    testWidgets('DriveGoSectionHeader renders title and action', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(wrapWithMaterial(
        DriveGoSectionHeader(
          title: 'Popular Cars',
          subtitle: 'Top rated in Mumbai',
          actionText: 'View All',
          onActionPressed: () => actionTapped = true,
        ),
      ));

      expect(find.text('Popular Cars'), findsOneWidget);
      expect(find.text('Top rated in Mumbai'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.text('View All'));
      expect(actionTapped, true);
    });

    testWidgets('Legacy components forward cleanly to DDS implementations', (tester) async {
      await tester.pumpWidget(wrapWithMaterial(
        Column(
          children: [
            AppButton(text: 'Legacy Button', onPressed: () {}),
            const AppCard(child: Text('Legacy Card')),
            const StatusBadge(status: 'APPROVED'),
            const PriceTag(amount: 1500, suffix: '/hr'),
            const SectionHeader(title: 'Legacy Header'),
          ],
        ),
      ));

      expect(find.text('Legacy Button'), findsOneWidget);
      expect(find.text('Legacy Card'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('₹1,500'), findsOneWidget);
      expect(find.text('Legacy Header'), findsOneWidget);
    });
  });
}
