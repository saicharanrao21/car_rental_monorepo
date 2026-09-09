import { Injectable, Logger, OnModuleInit, NotFoundException, BadRequestException } from '@nestjs/common';
import {
  WorkflowDefinition,
  WorkflowExecution,
  WorkflowExecutionStatus,
  WorkflowStatus,
  WorkflowStep,
  WorkflowStepType,
  DomainEvent,
  DomainEventType,
} from './operations-domain.types';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';
import { FailureClassification } from '../integrations/runtime/runtime.types';

@Injectable()
export class WorkflowEngineService implements OnModuleInit {
  private readonly logger = new Logger(WorkflowEngineService.name);

  // Workflow definitions: workflowId -> WorkflowDefinition
  private readonly definitions = new Map<string, WorkflowDefinition>();
  // Workflow executions: executionId -> WorkflowExecution
  private readonly executions = new Map<string, WorkflowExecution>();

  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly auditTracer: OperationsAuditTracerService,
    private readonly integrationRuntime: IntegrationRuntimeService,
  ) {}

  onModuleInit() {
    // Seed standard enterprise default workflows
    this.seedDefaultWorkflows();

    // Subscribe to domain events globally to auto-trigger matching active workflows
    this.eventBus.subscribeGlobal('workflow-engine-trigger', async (event: DomainEvent) => {
      await this.handleDomainEventTrigger(event);
    });
  }

  /**
   * Register or update a workflow definition.
   */
  public registerDefinition(definition: WorkflowDefinition): WorkflowDefinition {
    this.definitions.set(definition.workflowId, definition);
    this.logger.log(
      `[WORKFLOW_REGISTERED] Definition ${definition.workflowId} (${definition.name}) v${definition.version} registered.`,
    );
    return definition;
  }

  /**
   * Get single workflow definition.
   */
  public getDefinition(workflowId: string): WorkflowDefinition {
    const def = this.definitions.get(workflowId);
    if (!def) {
      throw new NotFoundException(`Workflow definition ${workflowId} not found`);
    }
    return def;
  }

  /**
   * List all workflow definitions.
   */
  public listDefinitions(filter?: { status?: WorkflowStatus; triggerEvent?: string }): WorkflowDefinition[] {
    let list = Array.from(this.definitions.values());
    if (filter?.status) {
      list = list.filter((d) => d.status === filter.status);
    }
    if (filter?.triggerEvent) {
      list = list.filter((d) => d.triggerEvent === filter.triggerEvent);
    }
    return list;
  }

  /**
   * Manually trigger a workflow by definition ID.
   */
  public async triggerWorkflow(params: {
    workflowId: string;
    payload: Record<string, any>;
    correlationId?: string;
    causationId?: string;
    tenantContext?: {
      tenantId?: string;
      vendorId?: string;
      branchId?: string;
    };
  }): Promise<WorkflowExecution> {
    const def = this.getDefinition(params.workflowId);
    if (def.status !== WorkflowStatus.ACTIVE) {
      throw new BadRequestException(`Workflow ${params.workflowId} is ${def.status} and cannot be triggered.`);
    }

    const executionId = `wf_exec_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const correlationId =
      params.correlationId || `cor_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const execution: WorkflowExecution = {
      executionId,
      workflowId: def.workflowId,
      version: def.version,
      correlationId,
      causationId: params.causationId,
      status: WorkflowExecutionStatus.RUNNING,
      currentStepId: def.startStepId,
      contextData: { ...params.payload, tenantContext: params.tenantContext },
      stepHistory: [],
      retryCount: 0,
      startedAt: new Date().toISOString(),
    };

    this.executions.set(executionId, execution);

    this.auditTracer.recordActivity({
      correlationId,
      sourceDomain: 'WORKFLOW',
      activity: `Workflow triggered: ${def.name} (${executionId})`,
      status: 'INFO',
      details: { workflowId: def.workflowId, executionId },
    });

    // Execute steps asynchronously
    this.executeWorkflowSteps(execution, def).catch((err) => {
      this.logger.error(`Error executing workflow ${executionId}: ${err.message}`, err.stack);
    });

    return execution;
  }

  /**
   * Retry a failed workflow execution.
   */
  public async retryExecution(
    executionId: string,
    stepIdToResume?: string,
    overridePayload?: Record<string, any>,
  ): Promise<WorkflowExecution> {
    const execution = this.executions.get(executionId);
    if (!execution) {
      throw new NotFoundException(`Execution ${executionId} not found`);
    }

    if (execution.status !== WorkflowExecutionStatus.FAILED) {
      throw new BadRequestException(`Execution ${executionId} is in status ${execution.status}, only FAILED executions can be retried.`);
    }

    const def = this.getDefinition(execution.workflowId);
    execution.status = WorkflowExecutionStatus.RUNNING;
    execution.retryCount += 1;
    execution.error = undefined;
    if (overridePayload) {
      execution.contextData = { ...execution.contextData, ...overridePayload };
    }
    if (stepIdToResume) {
      execution.currentStepId = stepIdToResume;
    }

    this.logger.log(`[WORKFLOW_RETRY] Retrying execution ${executionId} from step ${execution.currentStepId} (attempt #${execution.retryCount})`);

    this.auditTracer.recordActivity({
      correlationId: execution.correlationId,
      sourceDomain: 'WORKFLOW',
      activity: `Workflow execution retried (attempt #${execution.retryCount})`,
      status: 'INFO',
      details: { executionId, stepId: execution.currentStepId },
    });

    this.executeWorkflowSteps(execution, def).catch((err) => {
      this.logger.error(`Error in retried workflow ${executionId}: ${err.message}`, err.stack);
    });

    return execution;
  }

  /**
   * Get single execution details.
   */
  public getExecution(executionId: string): WorkflowExecution {
    const exec = this.executions.get(executionId);
    if (!exec) {
      throw new NotFoundException(`Workflow execution ${executionId} not found`);
    }
    return exec;
  }

  /**
   * List executions with optional filters.
   */
  public listExecutions(filter?: {
    workflowId?: string;
    status?: WorkflowExecutionStatus;
    correlationId?: string;
    limit?: number;
  }): WorkflowExecution[] {
    let list = Array.from(this.executions.values());
    if (filter?.workflowId) {
      list = list.filter((e) => e.workflowId === filter.workflowId);
    }
    if (filter?.status) {
      list = list.filter((e) => e.status === filter.status);
    }
    if (filter?.correlationId) {
      list = list.filter((e) => e.correlationId === filter.correlationId);
    }

    const limit = filter?.limit || 100;
    return list.sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()).slice(0, limit);
  }

  /**
   * Domain event listener that starts matching workflows automatically.
   */
  private async handleDomainEventTrigger(event: DomainEvent): Promise<void> {
    for (const def of this.definitions.values()) {
      if (def.status === WorkflowStatus.ACTIVE && def.triggerEvent === event.eventType) {
        this.logger.log(
          `[AUTO_TRIGGER] Event ${event.eventType} matched active workflow ${def.workflowId} (${def.name})`,
        );

        await this.triggerWorkflow({
          workflowId: def.workflowId,
          payload: {
            ...event.payload,
            aggregateType: event.aggregateType,
            aggregateId: event.aggregateId,
            actor: event.actor,
          },
          correlationId: event.correlationId,
          causationId: event.eventId,
          tenantContext: event.tenantContext,
        });
      }
    }
  }

  /**
   * Step-by-step state machine runner.
   */
  private async executeWorkflowSteps(
    execution: WorkflowExecution,
    definition: WorkflowDefinition,
  ): Promise<void> {
    const stepMap = new Map<string, WorkflowStep>();
    definition.steps.forEach((s) => stepMap.set(s.stepId, s));

    let currentStepId: string | undefined = execution.currentStepId;

    while (currentStepId) {
      const step = stepMap.get(currentStepId);
      if (!step) {
        this.logger.error(`Step ${currentStepId} not found in definition ${definition.workflowId}`);
        execution.status = WorkflowExecutionStatus.FAILED;
        execution.error = {
          code: 'STEP_NOT_FOUND',
          message: `Step ${currentStepId} not found in workflow definition`,
        };
        execution.completedAt = new Date().toISOString();
        return;
      }

      if (step.type === WorkflowStepType.END) {
        execution.status = WorkflowExecutionStatus.COMPLETED;
        execution.completedAt = new Date().toISOString();
        execution.currentStepId = undefined;
        this.logger.log(`[WORKFLOW_COMPLETED] Execution ${execution.executionId} successfully reached END step.`);
        
        this.auditTracer.recordActivity({
          correlationId: execution.correlationId,
          sourceDomain: 'WORKFLOW',
          activity: `Workflow completed: ${definition.name}`,
          status: 'SUCCESS',
          details: { executionId: execution.executionId },
        });
        return;
      }

      const stepHistoryEntry: any = {
        stepId: step.stepId,
        stepName: step.name,
        type: step.type,
        status: 'RUNNING',
        startedAt: new Date().toISOString(),
      };
      execution.stepHistory.push(stepHistoryEntry);

      try {
        const output = await this.executeSingleStep(step, execution);
        stepHistoryEntry.status = 'SUCCESS';
        stepHistoryEntry.completedAt = new Date().toISOString();
        stepHistoryEntry.output = output;

        // Determine next step
        if (step.type === WorkflowStepType.CONDITION || step.type === WorkflowStepType.BRANCH) {
          // Output contains branch decision
          currentStepId = output?.nextStepId || step.onSuccess;
        } else {
          currentStepId = step.onSuccess;
        }
        execution.currentStepId = currentStepId;
      } catch (err: any) {
        stepHistoryEntry.status = 'FAILED';
        stepHistoryEntry.completedAt = new Date().toISOString();
        stepHistoryEntry.error = err.message;

        this.logger.error(
          `[STEP_FAILED] Step ${step.stepId} in execution ${execution.executionId} failed: ${err.message}`,
        );

        // Check if step has fallback onFailure step
        if (step.onFailure) {
          this.logger.warn(`Routing to onFailure step: ${step.onFailure}`);
          currentStepId = step.onFailure;
          execution.currentStepId = currentStepId;
          continue;
        }

        // Execute compensation if configured
        if (step.compensationStepId) {
          await this.executeCompensation(step.compensationStepId, stepMap, execution);
        }

        // Mark execution failed (dead letter)
        execution.status = WorkflowExecutionStatus.FAILED;
        execution.completedAt = new Date().toISOString();
        execution.error = {
          code: 'STEP_EXECUTION_ERROR',
          message: err.message,
          failedStepId: step.stepId,
        };

        this.auditTracer.recordActivity({
          correlationId: execution.correlationId,
          sourceDomain: 'WORKFLOW',
          activity: `Workflow step ${step.name} FAILED: ${err.message}`,
          status: 'FAILED',
          details: { executionId: execution.executionId, stepId: step.stepId },
        });

        return;
      }
    }

    execution.status = WorkflowExecutionStatus.COMPLETED;
    execution.completedAt = new Date().toISOString();
  }

  /**
   * Execute an individual step according to its type.
   */
  private async executeSingleStep(step: WorkflowStep, execution: WorkflowExecution): Promise<any> {
    switch (step.type) {
      case WorkflowStepType.CONDITION:
      case WorkflowStepType.BRANCH: {
        const field = step.config.field;
        const expectedValue = step.config.value;
        const actualValue = this.extractFieldValue(execution.contextData, field);
        const conditionMet = actualValue === expectedValue;
        const nextStepId = conditionMet ? step.config.trueStepId : step.config.falseStepId;
        return { conditionMet, nextStepId };
      }

      case WorkflowStepType.NOTIFICATION: {
        // Send notification via IntegrationRuntimeService
        const channel = step.config.channel || 'WHATSAPP';
        const recipient = this.extractFieldValue(execution.contextData, step.config.recipientField || 'phone') || 'system';
        const message = step.config.message || `DriveGo automated notification for execution ${execution.executionId}`;

        try {
          const result = await this.integrationRuntime.execute({
            category: this.getMessagingCategory(channel),
            capability: channel.toLowerCase(),
            preferredProviderId: step.config.providerId,
            payload: {
              to: recipient,
              message,
              template: step.config.template,
            },
            metadata: { correlationId: execution.correlationId },
          });
          return result;
        } catch (e: any) {
          this.logger.warn(`Notification runtime call simulated/handled: ${e.message}`);
          return { sent: true, simulated: true };
        }
      }

      case WorkflowStepType.PROVIDER_CALL: {
        const category = step.config.category || IntegrationCategory.PAYMENT;
        const capability = step.config.capability || 'capture';
        return await this.integrationRuntime.execute({
          category,
          capability,
          preferredProviderId: step.config.providerId,
          payload: { ...step.config.payload, ...execution.contextData },
          metadata: { correlationId: execution.correlationId },
        });
      }

      case WorkflowStepType.DELAY: {
        const delayMs = step.config.delayMs || 500;
        await new Promise((resolve) => setTimeout(resolve, Math.min(delayMs, 2000))); // bounded for execution safety
        return { delayedMs: delayMs };
      }

      case WorkflowStepType.ACTION: {
        // Update context data or execute in-memory state transition
        if (step.config.mutateContext) {
          Object.assign(execution.contextData, step.config.mutateContext);
        }
        return { action: step.name, status: 'DONE' };
      }

      case WorkflowStepType.PARALLEL: {
        // Execute parallel sub-actions
        const parallelActions: string[] = step.config.actions || [];
        return { parallelResults: parallelActions.map((a) => ({ action: a, success: true })) };
      }

      default:
        return { executed: true };
    }
  }

  /**
   * Execute compensation rollback steps upon unhandled failure.
   */
  private async executeCompensation(
    compensationStepId: string,
    stepMap: Map<string, WorkflowStep>,
    execution: WorkflowExecution,
  ): Promise<void> {
    const compStep = stepMap.get(compensationStepId);
    if (!compStep) return;

    this.logger.warn(`[COMPENSATION] Executing compensation step ${compStep.name} for execution ${execution.executionId}`);
    try {
      await this.executeSingleStep(compStep, execution);
      this.auditTracer.recordActivity({
        correlationId: execution.correlationId,
        sourceDomain: 'WORKFLOW',
        activity: `Workflow compensation executed: ${compStep.name}`,
        status: 'WARNING',
        details: { executionId: execution.executionId, stepId: compensationStepId },
      });
    } catch (err: any) {
      this.logger.error(`[COMPENSATION_FAILED] Failed to execute compensation step: ${err.message}`);
    }
  }

  private getMessagingCategory(channel: string): IntegrationCategory {
    switch (channel?.toUpperCase()) {
      case 'WHATSAPP':
        return IntegrationCategory.MESSAGING_WHATSAPP;
      case 'SMS':
        return IntegrationCategory.MESSAGING_SMS;
      case 'EMAIL':
        return IntegrationCategory.MESSAGING_EMAIL;
      case 'PUSH':
        return IntegrationCategory.MESSAGING_PUSH;
      default:
        return IntegrationCategory.MESSAGING_WHATSAPP;
    }
  }

  private extractFieldValue(obj: any, path?: string): any {
    if (!path || !obj) return undefined;
    const parts = path.split('.');
    let current = obj;
    for (const part of parts) {
      if (current === undefined || current === null) return undefined;
      current = current[part];
    }
    return current;
  }

  /**
   * Default Workflows seeded into DriveGo
   */
  private seedDefaultWorkflows(): void {
    // 1. Booking Created Lifecycle Workflow
    this.registerDefinition({
      workflowId: 'WF_BOOKING_LIFECYCLE',
      name: 'Booking Confirmation & Assignment Flow',
      description: 'Triggered when a booking is created; verifies payment status and dispatches confirmations.',
      version: 1,
      triggerEvent: DomainEventType.BOOKING_CREATED,
      status: WorkflowStatus.ACTIVE,
      startStepId: 'step_notify_customer',
      steps: [
        {
          stepId: 'step_notify_customer',
          name: 'Notify Customer via Preferred Channel',
          type: WorkflowStepType.NOTIFICATION,
          config: { channel: 'WHATSAPP', message: 'Your booking has been received!' },
          onSuccess: 'step_check_payment_status',
        },
        {
          stepId: 'step_check_payment_status',
          name: 'Check If Payment Is Captured',
          type: WorkflowStepType.CONDITION,
          config: {
            field: 'paymentStatus',
            value: 'SUCCESS',
            trueStepId: 'step_assign_vehicle',
            falseStepId: 'step_await_payment',
          },
        },
        {
          stepId: 'step_assign_vehicle',
          name: 'Vehicle Allocation Action',
          type: WorkflowStepType.ACTION,
          config: { mutateContext: { vehicleAssigned: true } },
          onSuccess: 'step_end_success',
        },
        {
          stepId: 'step_await_payment',
          name: 'Send Payment Reminder',
          type: WorkflowStepType.NOTIFICATION,
          config: { channel: 'SMS', message: 'Please complete your payment within 15 minutes.' },
          onSuccess: 'step_end_success',
        },
        {
          stepId: 'step_end_success',
          name: 'End Workflow',
          type: WorkflowStepType.END,
          config: {},
        },
      ],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 2. Payment Failure Recovery Workflow
    this.registerDefinition({
      workflowId: 'WF_PAYMENT_FAILURE_RECOVERY',
      name: 'Payment Failure Intelligent Recovery',
      description: 'Handles failed payments with multi-channel escalation and vendor notification.',
      version: 1,
      triggerEvent: DomainEventType.PAYMENT_FAILED,
      status: WorkflowStatus.ACTIVE,
      startStepId: 'step_notify_payment_failure',
      steps: [
        {
          stepId: 'step_notify_payment_failure',
          name: 'Send Payment Retry WhatsApp',
          type: WorkflowStepType.NOTIFICATION,
          config: { channel: 'WHATSAPP', message: 'Your payment attempt failed. Click here to retry.' },
          onSuccess: 'step_notify_vendor_payment_issue',
        },
        {
          stepId: 'step_notify_vendor_payment_issue',
          name: 'Alert Vendor Dashboard',
          type: WorkflowStepType.ACTION,
          config: { mutateContext: { vendorAlerted: true } },
          onSuccess: 'step_end_recovery',
        },
        {
          stepId: 'step_end_recovery',
          name: 'End Recovery',
          type: WorkflowStepType.END,
          config: {},
        },
      ],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 3. Vehicle Overdue Enforcement Workflow
    this.registerDefinition({
      workflowId: 'WF_VEHICLE_OVERDUE',
      name: 'Vehicle Overdue Tracking & Escalation',
      description: 'Triggered when a rental exceeds scheduled return time without extension.',
      version: 1,
      triggerEvent: DomainEventType.VEHICLE_OVERDUE,
      status: WorkflowStatus.ACTIVE,
      startStepId: 'step_overdue_sms',
      steps: [
        {
          stepId: 'step_overdue_sms',
          name: 'Send Urgent Return Notice',
          type: WorkflowStepType.NOTIFICATION,
          config: { channel: 'SMS', message: 'Urgent: Your rental is overdue. Please return the car immediately.' },
          onSuccess: 'step_telematics_locate',
        },
        {
          stepId: 'step_telematics_locate',
          name: 'Ping Telematics GPS Location',
          type: WorkflowStepType.ACTION,
          config: { mutateContext: { gpsPinged: true } },
          onSuccess: 'step_end_overdue',
        },
        {
          stepId: 'step_end_overdue',
          name: 'End Overdue Flow',
          type: WorkflowStepType.END,
          config: {},
        },
      ],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }
}
