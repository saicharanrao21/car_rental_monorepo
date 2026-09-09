import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import {
  ApprovalRequest,
  ApprovalStatus,
  ApprovalStep,
  DomainEventType,
} from './operations-domain.types';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';

@Injectable()
export class ApprovalEngineService {
  private readonly logger = new Logger(ApprovalEngineService.name);

  // In-memory approval request store: requestId -> ApprovalRequest
  private readonly requests = new Map<string, ApprovalRequest>();

  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly auditTracer: OperationsAuditTracerService,
  ) {}

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
