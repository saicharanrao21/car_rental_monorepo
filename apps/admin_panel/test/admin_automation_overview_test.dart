import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_panel/features/automation/domain/models/operations_models.dart';
import 'package:admin_panel/features/automation/presentation/pages/admin_automation_overview_page.dart';
import 'package:admin_panel/features/automation/presentation/providers/admin_operations_providers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  final testWorkflows = [
    const WorkflowDefinitionModel(
      id: 'WF_BOOKING_LIFECYCLE',
      name: 'Booking Confirmation & Assignment Flow',
      version: 'v1.2',
      trigger: 'BOOKING_CREATED',
      status: 'ACTIVE',
      stepsCount: 3,
      lastRun: '2 mins ago',
      successRate: '99.8%',
      steps: [
        {'name': 'Booking Created Trigger', 'type': 'TRIGGER'},
        {'name': 'Dispatch WhatsApp Confirmation', 'type': 'NOTIFICATION'},
        {'name': 'Assign Vehicle from Hub', 'type': 'ACTION'},
      ],
    ),
  ];

  final testExecutions = [
    const WorkflowExecutionModel(
      id: 'wf_exec_88102',
      workflowId: 'WF_BOOKING_LIFECYCLE',
      workflowName: 'Booking Confirmation & Assignment Flow',
      correlationId: 'cor_bk_delhi_9921',
      status: 'COMPLETED',
      startedAt: '10:42:15 AM',
      duration: '840ms',
    ),
    const WorkflowExecutionModel(
      id: 'wf_exec_88103',
      workflowId: 'WF_BOOKING_LIFECYCLE',
      workflowName: 'Booking Confirmation & Assignment Flow',
      correlationId: 'cor_bk_delhi_9922',
      status: 'FAILED',
      startedAt: '10:45:00 AM',
      duration: '1200ms',
      error: 'Simulated Gateway Timeout',
    ),
  ];

  final testRules = [
    const AutomationRuleModel(
      id: 'RULE_BOOKING_24H_REMINDER',
      name: 'Send 24-Hour Pre-Pickup Reminder',
      trigger: 'BOOKING_CONFIRMED',
      predicate: 'booking.status == CONFIRMED',
      action: 'SEND_NOTIFICATION (WhatsApp -> SMS)',
      isEnabled: true,
      priority: 10,
    ),
  ];

  final testApprovals = [
    const ApprovalRequestModel(
      id: 'appr_ref_992',
      type: 'LARGE_REFUND',
      entity: 'Payment #PAY_55412 (₹48,500)',
      requestedBy: 'Support Executive',
      reason: 'Customer requested refund for trip breakdown',
      currentStep: 'Step 1 of 2: Branch Manager Review',
      status: 'PENDING',
      timeout: 'in 4 hours',
    ),
  ];

  final testSchedules = [
    const ScheduledJobModel(
      id: 'job_overdue_scan',
      name: 'Hourly Overdue Rental Scanner',
      type: 'CRON (0 * * * *)',
      nextRun: 'Today, 11:00 AM',
      status: 'SCHEDULED',
      timezone: 'Asia/Kolkata (IST)',
    ),
  ];

  Widget buildTestApp({int initialTab = 0}) {
    return ProviderScope(
      overrides: [
        adminWorkflowsProvider.overrideWith(() => MockWorkflowsNotifier(testWorkflows)),
        adminExecutionsProvider.overrideWith(() => MockExecutionsNotifier(testExecutions)),
        adminRulesProvider.overrideWith(() => MockRulesNotifier(testRules)),
        adminApprovalsProvider.overrideWith(() => MockApprovalsNotifier(testApprovals)),
        adminSchedulesProvider.overrideWith(() => MockSchedulesNotifier(testSchedules)),
      ],
      child: const MaterialApp(
        home: AdminAutomationOverviewPage(),
      ),
    );
  }

  testWidgets('AdminAutomationOverviewPage renders header and default Control Centre tab', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Verify Title & Phase L Active badge
    expect(find.text('Enterprise Operations & Automation Core'), findsOneWidget);
    expect(find.text('PHASE L ACTIVE'), findsOneWidget);
    expect(find.text('Trigger Maintenance Sweep'), findsOneWidget);

    // Verify Tabs & KPIs
    expect(find.text('Control Centre'), findsOneWidget);
    expect(find.text('Workflow Definitions'), findsOneWidget);
    expect(find.text('Executions & Retries'), findsOneWidget);
    expect(find.text('Automation Rules'), findsAtLeastNWidgets(1));
    expect(find.text('Approvals & HITL'), findsOneWidget);
    expect(find.text('Scheduled Jobs'), findsAtLeastNWidgets(1));
    expect(find.text('Correlation Timeline'), findsOneWidget);

    // Verify KPI Summary
    expect(find.text('Active Workflows'), findsOneWidget);
    expect(find.text('Executions Tracked'), findsOneWidget);
    expect(find.text('Pending Approvals'), findsAtLeastNWidgets(1));

    // Verify Overview Content
    expect(find.text('Recent Workflow Executions'), findsOneWidget);
    expect(find.text('Pending Human Approvals'), findsOneWidget);
  });

  testWidgets('Switching to Workflow Definitions tab displays pipelines', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Workflow Definitions Tab
    await tester.ensureVisible(find.text('Workflow Definitions').first);
    await tester.tap(find.text('Workflow Definitions').first);
    await tester.pumpAndSettle();

    expect(find.text('Declarative Workflow Definitions'), findsOneWidget);
    expect(find.text('Booking Confirmation & Assignment Flow'), findsOneWidget);
    expect(find.text('EXECUTION PIPELINE'), findsOneWidget);
    expect(find.text('STEP 1: TRIGGER'), findsOneWidget);
    expect(find.text('STEP 2: NOTIFICATION'), findsOneWidget);
    expect(find.text('STEP 3: ACTION'), findsOneWidget);
  });

  testWidgets('Switching to Executions & Retries tab displays execution details and retry button', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Executions & Retries Tab
    await tester.ensureVisible(find.text('Executions & Retries').first);
    await tester.tap(find.text('Executions & Retries').first);
    await tester.pumpAndSettle();

    expect(find.text('Workflow Executions & Failure Management'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('COMPLETED'), findsAtLeastNWidgets(1));
    expect(find.text('FAILED'), findsAtLeastNWidgets(1));
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Switching to Automation Rules tab renders rule cards and toggle', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Automation Rules Tab
    await tester.ensureVisible(find.text('Automation Rules').first);
    await tester.tap(find.text('Automation Rules').first);
    await tester.pumpAndSettle();

    expect(find.text('Dynamic Automation Rule Engine'), findsOneWidget);
    expect(find.text('Send 24-Hour Pre-Pickup Reminder'), findsOneWidget);
    expect(find.text('booking.status == CONFIRMED'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Switching to Approvals & HITL tab displays approval cards with actions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Approvals & HITL Tab
    await tester.ensureVisible(find.text('Approvals & HITL').first);
    await tester.tap(find.text('Approvals & HITL').first);
    await tester.pumpAndSettle();

    expect(find.text('Human-in-the-Loop (HITL) Approvals'), findsOneWidget);
    expect(find.text('Payment #PAY_55412 (₹48,500)'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve Step'), findsOneWidget);
  });

  testWidgets('Switching to Scheduled Jobs tab displays background jobs and Run Now', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Scheduled Jobs Tab
    await tester.ensureVisible(find.text('Scheduled Jobs').first);
    await tester.tap(find.text('Scheduled Jobs').first);
    await tester.pumpAndSettle();

    expect(find.text('Scheduled Background Jobs & Tickers'), findsOneWidget);
    expect(find.text('Hourly Overdue Rental Scanner'), findsOneWidget);
    expect(find.text('Run Now'), findsOneWidget);
  });

  testWidgets('Switching to Correlation Timeline tab displays cross-domain journey', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap Correlation Timeline Tab
    await tester.ensureVisible(find.text('Correlation Timeline').first);
    await tester.tap(find.text('Correlation Timeline').first);
    await tester.pumpAndSettle();

    expect(find.text('Unified Cross-Domain Operational Correlation Tracer'), findsOneWidget);
    expect(find.text('Active Correlation ID: cor_bk_delhi_9921'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
    expect(find.text('PAYMENTS'), findsOneWidget);
    expect(find.text('WORKFLOW'), findsOneWidget);
  });
}

class MockWorkflowsNotifier extends AutoDisposeAsyncNotifier<List<WorkflowDefinitionModel>> implements AdminWorkflowsNotifier {
  final List<WorkflowDefinitionModel> _items;
  MockWorkflowsNotifier(this._items);

  @override
  Future<List<WorkflowDefinitionModel>> build() async => _items;

  @override
  Future<void> refresh() async {}
}

class MockExecutionsNotifier extends AutoDisposeAsyncNotifier<List<WorkflowExecutionModel>> implements AdminExecutionsNotifier {
  final List<WorkflowExecutionModel> _items;
  MockExecutionsNotifier(this._items);

  @override
  Future<List<WorkflowExecutionModel>> build() async => _items;

  @override
  Future<void> retry(String id) async {}

  @override
  Future<void> refresh() async {}
}

class MockRulesNotifier extends AutoDisposeAsyncNotifier<List<AutomationRuleModel>> implements AdminRulesNotifier {
  final List<AutomationRuleModel> _items;
  MockRulesNotifier(this._items);

  @override
  Future<List<AutomationRuleModel>> build() async => _items;

  @override
  Future<void> toggleRule(String id, bool isEnabled) async {}

  @override
  Future<void> refresh() async {}
}

class MockApprovalsNotifier extends AutoDisposeAsyncNotifier<List<ApprovalRequestModel>> implements AdminApprovalsNotifier {
  final List<ApprovalRequestModel> _items;
  MockApprovalsNotifier(this._items);

  @override
  Future<List<ApprovalRequestModel>> build() async => _items;

  @override
  Future<void> recordDecision(String id, {required String decision, int stepIndex = 0}) async {}

  @override
  Future<void> refresh() async {}
}

class MockSchedulesNotifier extends AutoDisposeAsyncNotifier<List<ScheduledJobModel>> implements AdminSchedulesNotifier {
  final List<ScheduledJobModel> _items;
  MockSchedulesNotifier(this._items);

  @override
  Future<List<ScheduledJobModel>> build() async => _items;

  @override
  Future<void> runJob(String id) async {}

  @override
  Future<void> refresh() async {}
}
