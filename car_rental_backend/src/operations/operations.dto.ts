import { DomainEventType, WorkflowStatus, WorkflowStep, RulePredicate, RuleAction, ScheduleType } from './operations-domain.types';

export class CreateWorkflowDefinitionDto {
  name: string;
  description: string;
  triggerEvent: DomainEventType | string;
  startStepId: string;
  steps: WorkflowStep[];
  tenantScope?: {
    level: 'PLATFORM' | 'VENDOR' | 'BRANCH';
    scopeId?: string;
  };
}

export class TriggerWorkflowDto {
  workflowId: string;
  payload: Record<string, any>;
  correlationId?: string;
  causationId?: string;
  tenantContext?: {
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
  };
}

export class RetryWorkflowDto {
  stepId?: string;
  overridePayload?: Record<string, any>;
}

export class CreateAutomationRuleDto {
  name: string;
  description?: string;
  triggerEvent: DomainEventType | string;
  predicates: RulePredicate[];
  actions: RuleAction[];
  priority?: number;
  tenantScope?: {
    level: 'PLATFORM' | 'VENDOR' | 'BRANCH';
    scopeId?: string;
  };
}

export class UpdateAutomationRuleDto {
  name?: string;
  description?: string;
  predicates?: RulePredicate[];
  actions?: RuleAction[];
  isEnabled?: boolean;
  priority?: number;
}

export class CreateApprovalRequestDto {
  definitionType: 'VENDOR_ONBOARDING' | 'LARGE_REFUND' | 'DAMAGE_CLAIM_PAYOUT' | 'VEHICLE_RETIREMENT' | 'MANUAL_OVERRIDE';
  entityType: string;
  entityId: string;
  steps: Array<{
    stepIndex: number;
    title: string;
    approverRole: string;
    approverUserId?: string;
  }>;
  metadata?: Record<string, any>;
  timeoutMinutes?: number;
}

export class ApprovalDecisionDto {
  stepIndex: number;
  decision: 'APPROVED' | 'REJECTED';
  note?: string;
}

export class CreateScheduledJobDto {
  name: string;
  scheduleType: ScheduleType;
  cronExpression?: string;
  scheduledTime: string;
  payload: Record<string, any>;
  actionType: string;
  timezone?: string;
  maxRetries?: number;
}

export class PublishDomainEventDto {
  eventType: DomainEventType | string;
  aggregateType: 'BOOKING' | 'PAYMENT' | 'VEHICLE' | 'VENDOR' | 'CUSTOMER' | 'COMPLIANCE' | 'SYSTEM';
  aggregateId: string;
  payload: Record<string, any>;
  correlationId?: string;
  causationId?: string;
  tenantContext?: {
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
  };
}

export class UpdateCommunicationPreferenceDto {
  preferredChannel?: 'WHATSAPP' | 'SMS' | 'EMAIL' | 'PUSH';
  preferredLanguage?: string;
  optedOutChannels?: string[];
  bestSendTimeWindow?: {
    startHour: number;
    endHour: number;
  };
}
