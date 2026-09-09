import { Test, TestingModule } from '@nestjs/testing';
import { DomainEventBusService } from '../domain-event-bus.service';
import { OperationsAuditTracerService } from '../operations-audit-tracer.service';
import { CommunicationIntelligenceService } from '../communication-intelligence.service';
import { ApprovalEngineService } from '../approval-engine.service';
import { SchedulingEngineService } from '../scheduling-engine.service';
import { WorkflowEngineService } from '../workflow-engine.service';
import { AutomationRuleEngineService } from '../automation-rule-engine.service';
import { IntegrationRuntimeService } from '../../integrations/runtime/integration-runtime.service';
import {
  ApprovalStatus,
  DomainEvent,
  DomainEventType,
  RuleActionType,
  RuleOperator,
  ScheduleType,
  WorkflowExecutionStatus,
  WorkflowStatus,
  WorkflowStepType,
} from '../operations-domain.types';

describe('Phase L: Enterprise Operations, Automation & Intelligence Core', () => {
  let eventBus: DomainEventBusService;
  let auditTracer: OperationsAuditTracerService;
  let commIntelligence: CommunicationIntelligenceService;
  let approvalEngine: ApprovalEngineService;
  let schedulingEngine: SchedulingEngineService;
  let workflowEngine: WorkflowEngineService;
  let ruleEngine: AutomationRuleEngineService;
  let integrationRuntimeMock: jest.Mocked<Partial<IntegrationRuntimeService>>;

  beforeEach(async () => {
    integrationRuntimeMock = {
      execute: jest.fn().mockResolvedValue({
        success: true,
        data: { messageId: 'msg_test_123' },
        providerId: 'mock_provider',
        latencyMs: 15,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DomainEventBusService,
        OperationsAuditTracerService,
        CommunicationIntelligenceService,
        ApprovalEngineService,
        SchedulingEngineService,
        WorkflowEngineService,
        AutomationRuleEngineService,
        {
          provide: IntegrationRuntimeService,
          useValue: integrationRuntimeMock,
        },
      ],
    }).compile();

    eventBus = module.get<DomainEventBusService>(DomainEventBusService);
    auditTracer = module.get<OperationsAuditTracerService>(OperationsAuditTracerService);
    commIntelligence = module.get<CommunicationIntelligenceService>(CommunicationIntelligenceService);
    approvalEngine = module.get<ApprovalEngineService>(ApprovalEngineService);
    schedulingEngine = module.get<SchedulingEngineService>(SchedulingEngineService);
    workflowEngine = module.get<WorkflowEngineService>(WorkflowEngineService);
    ruleEngine = module.get<AutomationRuleEngineService>(AutomationRuleEngineService);

    // Initialize lifecycle hooks manually for isolated testing
    workflowEngine.onModuleInit();
    ruleEngine.onModuleInit();
  });

  afterEach(() => {
    schedulingEngine.onModuleDestroy();
    eventBus.onModuleDestroy();
  });

  // =========================================================================
  // 1. DOMAIN EVENT BUS & DEDUPLICATION TESTS
  // =========================================================================
  describe('Domain Event Bus & Deduplication', () => {
    it('should publish a domain event and deliver it to registered topic handlers', async () => {
      const receivedEvents: DomainEvent[] = [];
      eventBus.subscribe(DomainEventType.BOOKING_CREATED, 'test-handler', (event) => {
        receivedEvents.push(event);
      });

      const event = await eventBus.emit({
        eventType: DomainEventType.BOOKING_CREATED,
        aggregateType: 'BOOKING',
        aggregateId: 'bk_001',
        payload: { amount: 5000, customerId: 'cust_001' },
        correlationId: 'cor_test_1',
      });

      expect(receivedEvents.length).toBe(1);
      expect(receivedEvents[0].aggregateId).toBe('bk_001');
      expect(receivedEvents[0].correlationId).toBe('cor_test_1');
    });

    it('should drop duplicate events with identical eventId to prevent double-processing', async () => {
      const duplicateEnvelope: DomainEvent = {
        eventId: 'evt_fixed_dup_123',
        eventType: DomainEventType.PAYMENT_SUCCESS,
        aggregateType: 'PAYMENT',
        aggregateId: 'pay_001',
        timestamp: new Date().toISOString(),
        correlationId: 'cor_dup_1',
        version: 1,
        payload: { amount: 2500 },
      };

      const firstPublish = await eventBus.publish(duplicateEnvelope);
      expect(firstPublish.published).toBe(true);
      expect(firstPublish.duplicate).toBe(false);

      const secondPublish = await eventBus.publish(duplicateEnvelope);
      expect(secondPublish.published).toBe(false);
      expect(secondPublish.duplicate).toBe(true);
    });

    it('should store published events in memory and allow filtering by aggregate and correlationId', async () => {
      await eventBus.emit({
        eventType: DomainEventType.VEHICLE_ASSIGNED,
        aggregateType: 'VEHICLE',
        aggregateId: 'veh_99',
        payload: { licensePlate: 'KA-01-AB-1234' },
        correlationId: 'cor_audit_search',
      });

      const results = eventBus.queryEvents({ aggregateId: 'veh_99' });
      expect(results.length).toBeGreaterThanOrEqual(1);
      expect(results[0].aggregateId).toBe('veh_99');
      expect(results[0].correlationId).toBe('cor_audit_search');
    });
  });

  // =========================================================================
  // 2. CORRELATION AUDIT & TIMELINE TRACER TESTS
  // =========================================================================
  describe('Correlation Audit & Timeline Tracer', () => {
    it('should build chronological timeline across multiple domains sharing correlationId', () => {
      const corrId = 'cor_journey_100';

      auditTracer.recordActivity({
        correlationId: corrId,
        sourceDomain: 'CUSTOMER',
        activity: 'Customer signed up',
        status: 'SUCCESS',
      });

      auditTracer.recordActivity({
        correlationId: corrId,
        sourceDomain: 'BOOKINGS',
        activity: 'Booking created for BMW X5',
        status: 'SUCCESS',
      });

      auditTracer.recordActivity({
        correlationId: corrId,
        sourceDomain: 'PAYMENTS',
        activity: 'Payment captured via Razorpay',
        status: 'SUCCESS',
      });

      const timeline = auditTracer.getTimelineByCorrelationId(corrId);
      expect(timeline.length).toBe(3);
      expect(timeline[0].sourceDomain).toBe('CUSTOMER');
      expect(timeline[1].sourceDomain).toBe('BOOKINGS');
      expect(timeline[2].sourceDomain).toBe('PAYMENTS');
    });

    it('should sanitize and redact sensitive keys (passwords, tokens, api keys) in audit details', () => {
      const corrId = 'cor_security_test';

      const entry = auditTracer.recordActivity({
        correlationId: corrId,
        sourceDomain: 'INTEGRATIONS',
        activity: 'Provider credential verification',
        status: 'SUCCESS',
        details: {
          username: 'admin',
          password: 'super_secret_password',
          apiKey: 'pk_live_999999999',
          cardNumber: '4111222233334444',
          nested: {
            token: 'bearer_token_xyz',
            safeValue: 'OK',
          },
        },
      });

      expect(entry.details?.password).toBe('***REDACTED***');
      expect(entry.details?.apiKey).toBe('***REDACTED***');
      expect(entry.details?.cardNumber).toBe('***REDACTED***');
      expect(entry.details?.nested.token).toBe('***REDACTED***');
      expect(entry.details?.nested.safeValue).toBe('OK');
    });
  });

  // =========================================================================
  // 3. WORKFLOW ENGINE TESTS
  // =========================================================================
  describe('Workflow Engine', () => {
    it('should execute seeded default workflow WF_BOOKING_LIFECYCLE and branch conditionally', async () => {
      const execution = await workflowEngine.triggerWorkflow({
        workflowId: 'WF_BOOKING_LIFECYCLE',
        payload: {
          paymentStatus: 'SUCCESS',
          phone: '+919876543210',
        },
        correlationId: 'cor_wf_branch_test',
      });

      expect(execution.status).toBe(WorkflowExecutionStatus.RUNNING);
      expect(execution.workflowId).toBe('WF_BOOKING_LIFECYCLE');

      // Allow async step runner to complete
      await new Promise((resolve) => setTimeout(resolve, 100));

      const finished = workflowEngine.getExecution(execution.executionId);
      expect(finished.status).toBe(WorkflowExecutionStatus.COMPLETED);
      expect(finished.contextData.vehicleAssigned).toBe(true);
      expect(finished.stepHistory.length).toBeGreaterThanOrEqual(3);
    });

    it('should branch to payment reminder when paymentStatus is not SUCCESS', async () => {
      const execution = await workflowEngine.triggerWorkflow({
        workflowId: 'WF_BOOKING_LIFECYCLE',
        payload: {
          paymentStatus: 'PENDING',
          phone: '+919876543210',
        },
        correlationId: 'cor_wf_pending_payment',
      });

      await new Promise((resolve) => setTimeout(resolve, 100));

      const finished = workflowEngine.getExecution(execution.executionId);
      expect(finished.status).toBe(WorkflowExecutionStatus.COMPLETED);
      expect(finished.contextData.vehicleAssigned).toBeUndefined(); // Did not assign vehicle
    });

    it('should support workflow retry on failed executions', async () => {
      // Register a workflow with an intentional failing step
      const failingWf = workflowEngine.registerDefinition({
        workflowId: 'WF_FAIL_AND_RETRY',
        name: 'Retry Test Workflow',
        description: 'Tests failure and recovery',
        version: 1,
        triggerEvent: 'TEST_FAIL_EVENT',
        status: WorkflowStatus.ACTIVE,
        startStepId: 'step_flaky',
        steps: [
          {
            stepId: 'step_flaky',
            name: 'Flaky Step',
            type: WorkflowStepType.ACTION,
            config: {},
            onSuccess: 'step_final',
          },
          {
            stepId: 'step_final',
            name: 'Final Step',
            type: WorkflowStepType.END,
            config: {},
          },
        ],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      const execution = await workflowEngine.triggerWorkflow({
        workflowId: failingWf.workflowId,
        payload: {},
      });

      // Force failure state on execution for retry test
      execution.status = WorkflowExecutionStatus.FAILED;
      execution.error = { code: 'NETWORK_TIMEOUT', message: 'Temporary network timeout' };

      const retried = await workflowEngine.retryExecution(execution.executionId);
      expect(retried.retryCount).toBe(1);
      expect([WorkflowExecutionStatus.RUNNING, WorkflowExecutionStatus.COMPLETED]).toContain(retried.status);
    });
  });

  // =========================================================================
  // 4. AUTOMATION RULE ENGINE TESTS
  // =========================================================================
  describe('Automation Rule Engine', () => {
    it('should evaluate predicates correctly with AND/OR logic and comparison operators', () => {
      const predicates = [
        {
          field: 'payload.amount',
          operator: RuleOperator.GREATER_THAN,
          value: 1000,
          logic: 'AND' as const,
        },
        {
          field: 'payload.status',
          operator: RuleOperator.EQUALS,
          value: 'CONFIRMED',
          logic: 'AND' as const,
        },
      ];

      const matchingEvent: DomainEvent = {
        eventId: 'e1',
        eventType: DomainEventType.BOOKING_CONFIRMED,
        aggregateType: 'BOOKING',
        aggregateId: 'b1',
        timestamp: new Date().toISOString(),
        correlationId: 'c1',
        version: 1,
        payload: { amount: 3500, status: 'CONFIRMED' },
      };

      const nonMatchingEvent: DomainEvent = {
        eventId: 'e2',
        eventType: DomainEventType.BOOKING_CONFIRMED,
        aggregateType: 'BOOKING',
        aggregateId: 'b2',
        timestamp: new Date().toISOString(),
        correlationId: 'c2',
        version: 1,
        payload: { amount: 500, status: 'CONFIRMED' }, // amount too low
      };

      expect(ruleEngine.evaluatePredicates(predicates, matchingEvent)).toBe(true);
      expect(ruleEngine.evaluatePredicates(predicates, nonMatchingEvent)).toBe(false);
    });

    it('should match default RULE_PAYMENT_FAILURE_ALERT when PAYMENT_FAILED event occurs and trigger notification action', async () => {
      const event: DomainEvent = {
        eventId: 'evt_pay_fail_999',
        eventType: DomainEventType.PAYMENT_FAILED,
        aggregateType: 'PAYMENT',
        aggregateId: 'pay_999',
        timestamp: new Date().toISOString(),
        correlationId: 'cor_pay_fail_test',
        version: 1,
        payload: { amount: 4500, phone: '+919999888877' },
      };

      const matchedRulesCount = await ruleEngine.evaluateRulesForEvent(event);
      expect(matchedRulesCount).toBeGreaterThanOrEqual(1);
      expect(integrationRuntimeMock.execute).toHaveBeenCalled();
    });
  });

  // =========================================================================
  // 5. HUMAN-IN-THE-LOOP APPROVAL SUBSYSTEM TESTS
  // =========================================================================
  describe('Approval Engine Subsystem', () => {
    it('should advance multi-step approval and reach APPROVED overall status', async () => {
      const approval = await approvalEngine.createApprovalRequest({
        definitionType: 'LARGE_REFUND',
        entityType: 'PAYMENT',
        entityId: 'pay_ref_50000',
        requestedBy: { id: 'support_agent_1', role: 'SUPPORT' },
        steps: [
          { stepIndex: 0, title: 'Branch Manager Review', approverRole: 'VENDOR_ADMIN' },
          { stepIndex: 1, title: 'Finance Executive Approval', approverRole: 'SUPER_ADMIN' },
        ],
        metadata: { refundAmount: 50000, reason: 'Vehicle breakdown compensation' },
      });

      expect(approval.overallStatus).toBe(ApprovalStatus.PENDING);
      expect(approval.currentStepIndex).toBe(0);

      // 1. Approve step 0
      const afterStep0 = await approvalEngine.recordDecision({
        requestId: approval.requestId,
        stepIndex: 0,
        decision: 'APPROVED',
        decidedBy: { id: 'branch_mgr_42', role: 'VENDOR_ADMIN' },
        decisionNote: 'Verified breakdown logs, refund approved.',
      });

      expect(afterStep0.currentStepIndex).toBe(1);
      expect(afterStep0.overallStatus).toBe(ApprovalStatus.PENDING);

      // 2. Approve step 1
      const afterStep1 = await approvalEngine.recordDecision({
        requestId: approval.requestId,
        stepIndex: 1,
        decision: 'APPROVED',
        decidedBy: { id: 'super_admin_01', role: 'SUPER_ADMIN' },
        decisionNote: 'Finance disbursement sanctioned.',
      });

      expect(afterStep1.overallStatus).toBe(ApprovalStatus.APPROVED);
    });

    it('should immediately set overallStatus to REJECTED if any step is rejected', async () => {
      const approval = await approvalEngine.createApprovalRequest({
        definitionType: 'VENDOR_ONBOARDING',
        entityType: 'VENDOR',
        entityId: 'v_pending_123',
        requestedBy: { id: 'sales_rep', role: 'STAFF' },
        steps: [
          { stepIndex: 0, title: 'KYC Document Verification', approverRole: 'ADMIN' },
          { stepIndex: 1, title: 'Fleet Verification', approverRole: 'FLEET_MANAGER' },
        ],
      });

      const rejected = await approvalEngine.recordDecision({
        requestId: approval.requestId,
        stepIndex: 0,
        decision: 'REJECTED',
        decidedBy: { id: 'admin_kyc', role: 'ADMIN' },
        decisionNote: 'Invalid GST number provided.',
      });

      expect(rejected.overallStatus).toBe(ApprovalStatus.REJECTED);
      expect(rejected.steps[0].status).toBe(ApprovalStatus.REJECTED);
    });
  });

  // =========================================================================
  // 6. SCHEDULING ENGINE TESTS
  // =========================================================================
  describe('Scheduling Engine', () => {
    it('should schedule a one-time job and execute it via executeJobNow', async () => {
      const job = await schedulingEngine.scheduleJob({
        name: 'Overdue Rental Scanner',
        scheduleType: ScheduleType.ONE_TIME,
        scheduledTime: new Date(Date.now() + 60000).toISOString(),
        actionType: 'OVERDUE_SCAN',
        payload: { branchId: 'branch_bangalore_central' },
      });

      expect(job.status).toBe('SCHEDULED');

      const executed = await schedulingEngine.executeJobNow(job.jobId);
      expect(executed.status).toBe('COMPLETED');
      expect(executed.lastExecutedAt).toBeDefined();
    });

    it('should allow job cancellation before execution', async () => {
      const job = await schedulingEngine.scheduleJob({
        name: 'Vehicle Service Reminder',
        scheduleType: ScheduleType.ONE_TIME,
        scheduledTime: new Date(Date.now() + 3600000).toISOString(),
        actionType: 'SERVICE_REMINDER',
        payload: { vehicleId: 'v_100' },
      });

      const cancelled = schedulingEngine.cancelJob(job.jobId);
      expect(cancelled.status).toBe('CANCELLED');
    });
  });

  // =========================================================================
  // 7. CUSTOMER COMMUNICATION INTELLIGENCE TESTS
  // =========================================================================
  describe('Customer Communication Intelligence', () => {
    it('should prioritize user preferred channel and resolve channel fallback chain', () => {
      const userId = 'usr_comm_test_1';
      commIntelligence.updatePreferences(userId, {
        preferredChannel: 'SMS',
        optedOutChannels: ['EMAIL'],
      });

      const chain = commIntelligence.resolveChannelChain(userId);
      expect(chain[0]).toBe('SMS');
      expect(chain.includes('EMAIL')).toBe(false);
    });

    it('should adjust channel score dynamically based on delivery success and failure learning', () => {
      const userId = 'usr_comm_learn';
      const initialProfile = commIntelligence.getOrCreateProfile(userId);
      const initialScore = initialProfile.channelSuccessRates.WHATSAPP;

      // Simulate delivery failures
      commIntelligence.recordDeliveryFailure(userId, 'WHATSAPP');
      commIntelligence.recordDeliveryFailure(userId, 'WHATSAPP');

      const penalizedProfile = commIntelligence.getOrCreateProfile(userId);
      const penalizedScore = penalizedProfile.channelSuccessRates.WHATSAPP;
      expect(penalizedScore).toBeLessThan(initialScore);
      expect(penalizedProfile.deliveryFailureCount.WHATSAPP).toBe(2);

      // Simulate recovery success
      commIntelligence.recordDeliverySuccess(userId, 'WHATSAPP');
      const recoveredProfile = commIntelligence.getOrCreateProfile(userId);
      expect(recoveredProfile.channelSuccessRates.WHATSAPP).toBeGreaterThan(penalizedScore);
    });

    it('should provide AI extension point predicting optimal send timing', () => {
      const timingPrediction = commIntelligence.predictOptimalSendTime('usr_ai_test');
      expect(timingPrediction).toHaveProperty('recommendedDelayMinutes');
      expect(timingPrediction).toHaveProperty('confidenceScore');
      expect(timingPrediction.confidenceScore).toBeGreaterThan(0.5);
    });
  });
});
