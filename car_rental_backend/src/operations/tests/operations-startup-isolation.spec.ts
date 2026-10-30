import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { WorkflowEngineService } from '../workflow-engine.service';
import { ApprovalEngineService } from '../approval-engine.service';
import { SchedulingEngineService } from '../scheduling-engine.service';
import { DomainEventBusService } from '../domain-event-bus.service';
import { OperationsAuditTracerService } from '../operations-audit-tracer.service';
import { IntegrationRuntimeService } from '../../integrations/runtime/integration-runtime.service';
import { OperationsController } from '../operations.controller';
import { AutomationRuleEngineService } from '../automation-rule-engine.service';
import { CommunicationIntelligenceService } from '../communication-intelligence.service';
import { ApprovalStatus } from '../operations-domain.types';

describe('Operations Startup Isolation & Security Invariants', () => {
  let originalNodeEnv: string | undefined;
  let originalSeedFlag: string | undefined;

  beforeAll(() => {
    originalNodeEnv = process.env.NODE_ENV;
    originalSeedFlag = process.env.SEED_DEMO_OPERATIONS;
  });

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv;
    process.env.SEED_DEMO_OPERATIONS = originalSeedFlag;
  });

  describe('1. Production Startup Zero-Mock / Zero-Demo Invariant', () => {
    let workflowEngine: WorkflowEngineService;
    let approvalEngine: ApprovalEngineService;
    let schedulingEngine: SchedulingEngineService;
    let controller: OperationsController;

    beforeEach(async () => {
      // Simulate strict production environment
      process.env.NODE_ENV = 'production';
      delete process.env.SEED_DEMO_OPERATIONS;

      const module: TestingModule = await Test.createTestingModule({
        controllers: [OperationsController],
        providers: [
          DomainEventBusService,
          OperationsAuditTracerService,
          WorkflowEngineService,
          ApprovalEngineService,
          SchedulingEngineService,
          AutomationRuleEngineService,
          CommunicationIntelligenceService,
          {
            provide: IntegrationRuntimeService,
            useValue: { execute: jest.fn() },
          },
        ],
      }).compile();

      workflowEngine = module.get<WorkflowEngineService>(WorkflowEngineService);
      approvalEngine = module.get<ApprovalEngineService>(ApprovalEngineService);
      schedulingEngine = module.get<SchedulingEngineService>(SchedulingEngineService);
      controller = module.get<OperationsController>(OperationsController);

      // Invoke module init
      workflowEngine.onModuleInit();
      approvalEngine.onModuleInit();
      schedulingEngine.onModuleInit();
    });

    afterEach(() => {
      schedulingEngine.onModuleDestroy();
    });

    it('should register standard workflow blueprints but ZERO execution history on production boot', () => {
      const blueprints = workflowEngine.listDefinitions();
      expect(blueprints.length).toBeGreaterThanOrEqual(3);
      expect(blueprints.map((b) => b.workflowId)).toContain('WF_BOOKING_LIFECYCLE');

      const executions = workflowEngine.listExecutions();
      expect(executions.length).toBe(0);
    });

    it('should boot with ZERO pending approval requests in production', () => {
      const pendingApprovals = approvalEngine.listApprovalRequests({ status: ApprovalStatus.PENDING });
      expect(pendingApprovals.length).toBe(0);

      const allApprovals = approvalEngine.listApprovalRequests();
      expect(allApprovals.length).toBe(0);
    });

    it('should boot with ZERO scheduled background jobs in production', () => {
      const jobs = schedulingEngine.listJobs();
      expect(jobs.length).toBe(0);
    });

    it('should strictly reject calling demo seeding methods directly in production', () => {
      expect(() => workflowEngine.seedDemoExecutions()).toThrow(BadRequestException);
      expect(() => approvalEngine.seedDefaultApprovals()).toThrow(BadRequestException);
      expect(() => schedulingEngine.seedDefaultJobs()).toThrow(BadRequestException);
    });

    it('should reject seedDemoOperations HTTP endpoint in production environment', () => {
      expect(() => controller.seedDemoOperations()).toThrow(BadRequestException);
    });
  });

  describe('2. Non-Production Explicit Demo Seeding', () => {
    let workflowEngine: WorkflowEngineService;
    let approvalEngine: ApprovalEngineService;
    let schedulingEngine: SchedulingEngineService;

    beforeEach(async () => {
      process.env.NODE_ENV = 'development';
      process.env.SEED_DEMO_OPERATIONS = 'true';

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          DomainEventBusService,
          OperationsAuditTracerService,
          WorkflowEngineService,
          ApprovalEngineService,
          SchedulingEngineService,
          {
            provide: IntegrationRuntimeService,
            useValue: { execute: jest.fn() },
          },
        ],
      }).compile();

      workflowEngine = module.get<WorkflowEngineService>(WorkflowEngineService);
      approvalEngine = module.get<ApprovalEngineService>(ApprovalEngineService);
      schedulingEngine = module.get<SchedulingEngineService>(SchedulingEngineService);

      workflowEngine.onModuleInit();
      approvalEngine.onModuleInit();
      schedulingEngine.onModuleInit();
    });

    afterEach(() => {
      schedulingEngine.onModuleDestroy();
    });

    it('should seed demo executions, approvals, and jobs when SEED_DEMO_OPERATIONS is true', () => {
      const executions = workflowEngine.listExecutions();
      expect(executions.length).toBe(3);

      const approvals = approvalEngine.listApprovalRequests();
      expect(approvals.length).toBe(2);

      const jobs = schedulingEngine.listJobs();
      expect(jobs.length).toBe(3);
    });
  });

  describe('3. Human-in-the-Loop Approval Step Ordering & Role Verification', () => {
    let approvalEngine: ApprovalEngineService;

    beforeEach(async () => {
      process.env.NODE_ENV = 'test';
      delete process.env.SEED_DEMO_OPERATIONS;

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          DomainEventBusService,
          OperationsAuditTracerService,
          ApprovalEngineService,
        ],
      }).compile();

      approvalEngine = module.get<ApprovalEngineService>(ApprovalEngineService);
    });

    it('should prevent out-of-order step approval and enforce currentStepIndex', async () => {
      const req = await approvalEngine.createApprovalRequest({
        definitionType: 'LARGE_REFUND',
        entityType: 'PAYMENT',
        entityId: 'pay_9921',
        requestedBy: { id: 'usr_support', role: 'SUPPORT_EXECUTIVE' },
        steps: [
          { stepIndex: 0, title: 'Branch Review', approverRole: 'BRANCH_MANAGER' },
          { stepIndex: 1, title: 'Finance Signoff', approverRole: 'FINANCE_DIRECTOR' },
        ],
      });

      // Attempt to decide step 1 before step 0
      await expect(
        approvalEngine.recordDecision({
          requestId: req.requestId,
          stepIndex: 1,
          decision: 'APPROVED',
          decidedBy: { id: 'usr_fin', role: 'FINANCE_DIRECTOR' },
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject approval if user does not satisfy required step role', async () => {
      const req = await approvalEngine.createApprovalRequest({
        definitionType: 'LARGE_REFUND',
        entityType: 'PAYMENT',
        entityId: 'pay_9922',
        requestedBy: { id: 'usr_support', role: 'SUPPORT_EXECUTIVE' },
        steps: [
          { stepIndex: 0, title: 'Branch Review', approverRole: 'BRANCH_MANAGER' },
        ],
      });

      // User with SUPPORT_EXECUTIVE role attempting to approve step requiring BRANCH_MANAGER
      await expect(
        approvalEngine.recordDecision({
          requestId: req.requestId,
          stepIndex: 0,
          decision: 'APPROVED',
          decidedBy: { id: 'usr_support', role: 'SUPPORT_EXECUTIVE' },
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should allow designated approverRole or SUPER_ADMIN / ADMIN to approve', async () => {
      const req = await approvalEngine.createApprovalRequest({
        definitionType: 'LARGE_REFUND',
        entityType: 'PAYMENT',
        entityId: 'pay_9923',
        requestedBy: { id: 'usr_support', role: 'SUPPORT_EXECUTIVE' },
        steps: [
          { stepIndex: 0, title: 'Branch Review', approverRole: 'BRANCH_MANAGER' },
        ],
      });

      const approved = await approvalEngine.recordDecision({
        requestId: req.requestId,
        stepIndex: 0,
        decision: 'APPROVED',
        decidedBy: { id: 'usr_mgr_1', role: 'BRANCH_MANAGER' },
      });

      expect(approved.overallStatus).toBe(ApprovalStatus.APPROVED);
    });

    it('should strictly reject self-approval and enforce segregation of duties', async () => {
      const req = await approvalEngine.createApprovalRequest({
        definitionType: 'LARGE_REFUND',
        entityType: 'PAYMENT',
        entityId: 'pay_9924',
        requestedBy: { id: 'usr_dual_control', role: 'ADMIN' },
        steps: [
          { stepIndex: 0, title: 'Admin Review', approverRole: 'ADMIN' },
        ],
      });

      // Same user attempting to decide their own request
      await expect(
        approvalEngine.recordDecision({
          requestId: req.requestId,
          stepIndex: 0,
          decision: 'APPROVED',
          decidedBy: { id: 'usr_dual_control', role: 'ADMIN' },
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('4. Operations Controller Authorization Invariants', () => {
    let controller: OperationsController;

    beforeEach(async () => {
      process.env.NODE_ENV = 'test';
      delete process.env.SEED_DEMO_OPERATIONS;

      const module: TestingModule = await Test.createTestingModule({
        controllers: [OperationsController],
        providers: [
          DomainEventBusService,
          OperationsAuditTracerService,
          WorkflowEngineService,
          ApprovalEngineService,
          SchedulingEngineService,
          AutomationRuleEngineService,
          CommunicationIntelligenceService,
          {
            provide: IntegrationRuntimeService,
            useValue: { execute: jest.fn() },
          },
        ],
      }).compile();

      controller = module.get<OperationsController>(OperationsController);
    });

    it('should throw UnauthorizedException if req.user is absent when creating approval request', () => {
      expect(() =>
        controller.createApprovalRequest(
          {
            definitionType: 'LARGE_REFUND',
            entityType: 'PAYMENT',
            entityId: 'pay_9999',
            steps: [{ stepIndex: 0, title: 'Review', approverRole: 'ADMIN' }],
          },
          { user: null },
        ),
      ).toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException if req.user is absent when recording decision', () => {
      expect(() =>
        controller.recordApprovalDecision(
          'appr_fake',
          { stepIndex: 0, decision: 'APPROVED' },
          { user: null },
        ),
      ).toThrow(UnauthorizedException);
    });
  });
});
