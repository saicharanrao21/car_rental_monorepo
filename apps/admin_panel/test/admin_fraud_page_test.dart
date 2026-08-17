import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:admin_panel/features/fraud/domain/repositories/fraud_repository.dart';
import 'package:admin_panel/features/fraud/presentation/pages/admin_fraud_page.dart';
import 'package:admin_panel/features/fraud/presentation/providers/fraud_providers.dart';

class TestMockFraudRepository implements FraudRepository {
  final List<RiskAssessmentModel> assessments;

  TestMockFraudRepository(this.assessments);

  @override
  Future<FraudSummaryModel> getSummary() async {
    return const FraudSummaryModel(
      totalEvents: 3,
      criticalCount: 1,
      highCount: 1,
      mediumCount: 1,
      lowCount: 0,
      pendingReviewCount: 2,
    );
  }

  @override
  Future<List<RiskAssessmentModel>> getAssessments({
    String? riskLevel,
    String? status,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    var filtered = assessments;
    if (riskLevel != null && riskLevel.isNotEmpty) {
      filtered = filtered
          .where((a) => a.riskLevel.displayName == riskLevel.toUpperCase())
          .toList();
    }
    if (status != null && status.isNotEmpty) {
      filtered = filtered
          .where((a) => a.status.toUpperCase() == status.toUpperCase())
          .toList();
    }
    if (userId != null && userId.isNotEmpty) {
      filtered = filtered.where((a) => a.userId == userId).toList();
    }
    return filtered;
  }

  @override
  Future<RiskAssessmentModel> getUserRiskProfile(String userId) async {
    return assessments.first;
  }

  @override
  Future<bool> resolveAssessment(
    String assessmentId, {
    required String status,
    required String adminNotes,
  }) async {
    return true;
  }
}

void main() {
  final sampleAssessments = [
    RiskAssessmentModel(
      id: 'risk_001',
      userId: 'usr_001',
      userName: 'Vikram Mehta',
      userPhone: '+919876543210',
      score: 85,
      riskLevel: RiskLevel.critical,
      action: RiskAction.block,
      signals: const [
        RiskSignalModel(
          code: 'BANNED_USER',
          description: 'User account flagged administratively',
          scoreDelta: 100,
        ),
      ],
      status: 'PENDING_REVIEW',
      adminNotes: null,
      resolvedBy: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    RiskAssessmentModel(
      id: 'risk_002',
      userId: 'usr_002',
      userName: 'Rahul Sharma',
      userPhone: '+919876543211',
      score: 65,
      riskLevel: RiskLevel.high,
      action: RiskAction.reviewRequired,
      signals: const [
        RiskSignalModel(
          code: 'DUPLICATE_DRIVING_LICENCE',
          description: 'Driving Licence registered on 2 other accounts',
          scoreDelta: 40,
        ),
      ],
      status: 'PENDING_REVIEW',
      adminNotes: null,
      resolvedBy: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  testWidgets('AdminFraudPage renders summary metrics, filters, and assessments table', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fraudRepositoryProvider.overrideWithValue(TestMockFraudRepository(sampleAssessments)),
        ],
        child: const MaterialApp(
          home: AdminFraudPage(),
        ),
      ),
    );

    // Initial pump & allow FutureProviders to settle
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Fraud Detection & Risk Scoring'), findsOneWidget);
    expect(find.text('Refresh Alerts'), findsOneWidget);

    // Verify KPI Cards
    expect(find.text('Total Events'), findsOneWidget);
    expect(find.text('Critical Alerts'), findsOneWidget);
    expect(find.text('High Risk Queue'), findsOneWidget);
    expect(find.text('Pending Review'), findsOneWidget);

    // Verify Filter Rows
    expect(find.text('Filter Risk:'), findsOneWidget);
    expect(find.text('CRITICAL'), findsWidgets);
    expect(find.text('HIGH'), findsWidgets);

    // Verify Table Elements
    expect(find.text('Vikram Mehta'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('BANNED_USER (+100)'), findsOneWidget);
    expect(find.text('DUPLICATE_DRIVING_LICENCE (+40)'), findsOneWidget);
  });

  testWidgets('AdminFraudPage opens review dialog and resolves assessment', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fraudRepositoryProvider.overrideWithValue(TestMockFraudRepository(sampleAssessments)),
        ],
        child: const MaterialApp(
          home: AdminFraudPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the first 'Review' button
    final reviewButtons = find.text('Review');
    expect(reviewButtons, findsWidgets);
    await tester.tap(reviewButtons.first);
    await tester.pumpAndSettle();

    // Verify Dialog contents
    expect(find.text('Review Risk Assessment: Vikram Mehta'), findsOneWidget);
    expect(find.text('Calculated Score: 85 / 100'), findsOneWidget);
    expect(find.text('Triggered Security Signals:'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);
    expect(find.text('Dismiss Alert'), findsOneWidget);

    // Enter admin notes
    await tester.enterText(
      find.byType(TextField),
      'Account unblocked following manual KYC validation.',
    );
    await tester.pump();

    // Tap Resolve
    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();

    // Verify dialog closed
    expect(find.text('Review Risk Assessment: Vikram Mehta'), findsNothing);
  });
}
