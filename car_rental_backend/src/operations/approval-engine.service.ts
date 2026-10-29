import { Injectable, Logger, OnModuleInit, NotFoundException, BadRequestException } from '@nestjs/common';
import {
  ApprovalRequest,
  ApprovalStatus,
  ApprovalStep,
  DomainEventType,
} from './operations-domain.types';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';

@Injectable()
export class ApprovalEngineService implements OnModuleInit {
  private readonly logger = new Logger(ApprovalEngineService.name);

  // In-memory approval request store: requestId -> ApprovalRequest
  private readonly requests = new Map<string, ApprovalRequest>();

  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly auditTracer: OperationsAuditTracerService,
  ) {}

  onModuleInit() {
    this.seedDefaultApprovals();
  }

  private seedDefaultApprovals() {
    const now = Date.now();
    this.requests.set('appr_ref_992', {
      requestId: 'appr_ref_992',
      definitionType: 'LARGE_REFUND',
      entityType: 'PAYMENT',
      entityId: 'PAY_55412',
      requestedBy: { id: 'usr_support_ananya', role: 'SUPPORT_EXECUTIVE' },
      steps: [
        {
          stepIndex: 0,
          title: 'Branch Manager Review',
          approverRole: 'BRANCH_MANAGER',
          status: ApprovalStatus.PENDING,
        },
        {
          stepIndex: 1,
          title: 'Finance Director Signoff',
          approverRole: 'ADMIN',
          status: ApprovalStatus.PENDING,
        },
      ],
      currentStepIndex: 0,
      overallStatus: ApprovalStatus.PENDING,
      metadata: {
        amount: 48500,
        currency: 'INR',
        reason: 'Customer requested refund for trip breakdown at highway',
        customerName: 'Ananya Roy',
      },
      timeoutAt: new Date(now + 4 * 3600 * 1000).toISOString(),
      createdAt: new Date(now - 3600 * 1000).toISOString(),
      updatedAt: new Date(now - 3600 * 1000).toISOString(),
    });

    this.requests.set('appr_vnd_104', {
      requestId: 'appr_vnd_104',
      definitionType: 'VENDOR_ONBOARDING',
      entityType: 'VENDOR',
      entityId: 'vnd_apex_blr',
      requestedBy: { id: 'usr_partner_rohit', role: 'PARTNER_ACQUISITION' },
      steps: [
        {
          stepIndex: 0,
          title: 'Compliance & GST Verification',
          approverRole: 'ADMIN',
          status: ApprovalStatus.APPROVED,
          decidedBy: 'admin_sys',
          decidedAt: new Date(now - 7200 * 1000).toISOString(),
        },
        {
          stepIndex: 1,
          title: 'Fleet Inspection & Contract Approval',
          approverRole: 'ADMIN',
          status: ApprovalStatus.PENDING,
        },
      ],
      currentStepIndex: 1,
      overallStatus: ApprovalStatus.PENDING,
      metadata: {
        vendorName: 'Apex Mobility Pvt Ltd',
        vehicleCount: 14,
        city: 'Hyderabad',
        reason: 'Tier-1 commercial fleet partner onboarding in Hyderabad',
        correlationId: 'cor_vnd_apex_blr',
      },
      timeoutAt: new Date(now + 18 * 3600 * 1000).toISOString(),
      createdAt: new Date(now - 14400 * 1000).toISOString(),
      updatedAt: new Date(now - 7200 * 1000).toISOString(),
    });
  }

  /**
   * Create a new Human-in-the-loop approval request.
   */
  public async createApprovalRequest(params: {
    definitionType: 'VENDOR_ONBOARDING' | 'LARGE_REFUND' | 'DAMAGE_CLAIM_PAYOUT' | 'VEHICLE_RETIREMENT' | 'MANUAL_OVERRIDE';
    entityType: string;
    entityId: string;
    requestedBy: { id: string; role: string };
    steps: Array<{
      stepIndex: number;
      title: string;
      approverRole: string;
      approverUserId?: string;
    }>;
    metadata?: Record<string, any>;
    timeoutMinutes?: number;
    correlationId?: string;
  }): Promise<ApprovalRequest> {
    const requestId = `appr_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const correlationId = params.correlationId || `cor_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const steps: ApprovalStep[] = params.steps.map((s, index) => ({
      stepIndex: s.stepIndex ?? index,
      title: s.title,
      approverRole: s.approverRole,
      approverUserId: s.approverUserId,
      status: index === 0 ? ApprovalStatus.PENDING : ApprovalStatus.PENDING,
    }));

    const timeoutAt = params.timeoutMinutes
      ? new Date(Date.now() + params.timeoutMinutes * 60 * 1000).toISOString()
      : undefined;

    const request: ApprovalRequest = {
      requestId,
      definitionType: params.definitionType,
      entityType: params.entityType,
      entityId: params.entityId,
      requestedBy: params.requestedBy,
      currentStepIndex: 0,
      steps,
      overallStatus: ApprovalStatus.PENDING,
      metadata: params.metadata || {},
      timeoutAt,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    this.requests.set(requestId, request);

    this.logger.log(
      `[APPROVAL_CREATED] Request ${requestId} (${params.definitionType} for ${params.entityType}#${params.entityId}) created by ${params.requestedBy.id}`,
    );

    this.auditTracer.recordActivity({
      correlationId,
      sourceDomain: 'APPROVAL',
      activity: `Approval request created: ${params.definitionType} for ${params.entityType}#${params.entityId}`,
      status: 'INFO',
      details: { requestId, definitionType: params.definitionType, entityId: params.entityId },
    });

    return request;
  }

  /**
   * Submit an approval or rejection decision on a specific step.
   */
  public async recordDecision(params: {
    requestId: string;
    stepIndex: number;
    decision: 'APPROVED' | 'REJECTED';
    decidedBy: { id: string; role: string };
    decisionNote?: string;
    correlationId?: string;
  }): Promise<ApprovalRequest> {
    const request = this.requests.get(params.requestId);
    if (!request) {
      throw new NotFoundException(`Approval request with ID ${params.requestId} not found`);
    }

    if (request.overallStatus !== ApprovalStatus.PENDING) {
      throw new BadRequestException(
        `Approval request is already resolved with status ${request.overallStatus}`,
      );
    }

    const step = request.steps.find((s) => s.stepIndex === params.stepIndex);
    if (!step) {
      throw new BadRequestException(`Step index ${params.stepIndex} does not exist in request`);
    }

    if (step.status !== ApprovalStatus.PENDING) {
      throw new BadRequestException(`Step ${params.stepIndex} has already been decided: ${step.status}`);
    }

    step.decidedBy = params.decidedBy.id;
    step.decisionNote = params.decisionNote;
    step.decidedAt = new Date().toISOString();

    const corrId = params.correlationId || `cor_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (params.decision === 'REJECTED') {
      step.status = ApprovalStatus.REJECTED;
      request.overallStatus = ApprovalStatus.REJECTED;
      request.updatedAt = new Date().toISOString();

      this.logger.warn(`[APPROVAL_REJECTED] Request ${request.requestId} rejected at step ${step.stepIndex}`);

      this.auditTracer.recordActivity({
        correlationId: corrId,
        sourceDomain: 'APPROVAL',
        activity: `Approval step ${step.stepIndex} REJECTED by ${params.decidedBy.id}: ${params.decisionNote || 'No note'}`,
        status: 'WARNING',
        details: { requestId: request.requestId, stepIndex: step.stepIndex, note: params.decisionNote },
      });

      return request;
    }

    // Step approved
    step.status = ApprovalStatus.APPROVED;
    const nextStepIndex = params.stepIndex + 1;

    if (nextStepIndex < request.steps.length) {
      request.currentStepIndex = nextStepIndex;
      this.logger.log(`[APPROVAL_ADVANCED] Request ${request.requestId} advanced to step ${nextStepIndex}`);
    } else {
      // All steps approved
      request.overallStatus = ApprovalStatus.APPROVED;
      this.logger.log(`[APPROVAL_COMPLETED] Request ${request.requestId} fully approved across all ${request.steps.length} steps`);
    }

    request.updatedAt = new Date().toISOString();

    this.auditTracer.recordActivity({
      correlationId: corrId,
      sourceDomain: 'APPROVAL',
      activity: `Approval step ${step.stepIndex} APPROVED by ${params.decidedBy.id}`,
      status: 'SUCCESS',
      details: {
        requestId: request.requestId,
        stepIndex: step.stepIndex,
        overallStatus: request.overallStatus,
      },
    });

    return request;
  }

  /**
   * Get single approval request by ID.
   */
  public getApprovalRequest(requestId: string): ApprovalRequest {
    const request = this.requests.get(requestId);
    if (!request) {
      throw new NotFoundException(`Approval request ${requestId} not found`);
    }
    return request;
  }

  /**
   * List all approval requests with optional filters.
   */
  public listApprovalRequests(filter?: {
    status?: ApprovalStatus;
    definitionType?: string;
    entityType?: string;
    entityId?: string;
  }): ApprovalRequest[] {
    let list = Array.from(this.requests.values());

    if (filter?.status) {
      list = list.filter((r) => r.overallStatus === filter.status);
    }
    if (filter?.definitionType) {
      list = list.filter((r) => r.definitionType === filter.definitionType);
    }
    if (filter?.entityType) {
      list = list.filter((r) => r.entityType === filter.entityType);
    }
    if (filter?.entityId) {
      list = list.filter((r) => r.entityId === filter.entityId);
    }

    return list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }
}
