import { Role } from '@prisma/client';

/**
 * Enterprise Domain Event Types across DriveGo Ecosystem
 */
export enum DomainEventType {
  BOOKING_CREATED = 'BOOKING_CREATED',
  BOOKING_CONFIRMED = 'BOOKING_CONFIRMED',
  BOOKING_CANCELLED = 'BOOKING_CANCELLED',
  BOOKING_COMPLETED = 'BOOKING_COMPLETED',
  PAYMENT_INITIATED = 'PAYMENT_INITIATED',
  PAYMENT_SUCCESS = 'PAYMENT_SUCCESS',
  PAYMENT_FAILED = 'PAYMENT_FAILED',
  REFUND_INITIATED = 'REFUND_INITIATED',
  REFUND_SUCCESS = 'REFUND_SUCCESS',
  REFUND_FAILED = 'REFUND_FAILED',
  KYC_SUBMITTED = 'KYC_SUBMITTED',
  KYC_APPROVED = 'KYC_APPROVED',
  KYC_REJECTED = 'KYC_REJECTED',
  VEHICLE_ASSIGNED = 'VEHICLE_ASSIGNED',
  VEHICLE_PICKED_UP = 'VEHICLE_PICKED_UP',
  VEHICLE_RETURNED = 'VEHICLE_RETURNED',
  VEHICLE_OVERDUE = 'VEHICLE_OVERDUE',
  MAINTENANCE_DUE = 'MAINTENANCE_DUE',
  DOCUMENT_EXPIRING = 'DOCUMENT_EXPIRING',
  DOCUMENT_EXPIRED = 'DOCUMENT_EXPIRED',
  USER_CREATED = 'USER_CREATED',
  VENDOR_CREATED = 'VENDOR_CREATED',
  VENDOR_APPROVED = 'VENDOR_APPROVED',
  DISPUTE_RAISED = 'DISPUTE_RAISED',
  TELEMATICS_ALERT = 'TELEMATICS_ALERT',
}

/**
 * Standardized Domain Event Envelope
 */
export interface DomainEvent<T = any> {
  eventId: string;
  eventType: DomainEventType | string;
  aggregateType: 'BOOKING' | 'PAYMENT' | 'VEHICLE' | 'VENDOR' | 'CUSTOMER' | 'COMPLIANCE' | 'SYSTEM';
  aggregateId: string;
  tenantContext?: {
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
  };
  actor?: {
    id: string;
    role: Role | 'SYSTEM' | 'AUTOMATION' | 'INTEGRATION';
    type?: string;
  };
  timestamp: string;
  correlationId: string;
  causationId?: string;
  version: number;
  payload: T;
}

/**
 * Workflow Status & Step Types
 */
export enum WorkflowStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  PAUSED = 'PAUSED',
  DEPRECATED = 'DEPRECATED',
}

export enum WorkflowExecutionStatus {
  PENDING = 'PENDING',
  RUNNING = 'RUNNING',
  WAITING_APPROVAL = 'WAITING_APPROVAL',
  WAITING_DELAY = 'WAITING_DELAY',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  CANCELLED = 'CANCELLED',
  COMPENSATING = 'COMPENSATING',
  COMPENSATED = 'COMPENSATED',
}

export enum WorkflowStepType {
  TRIGGER = 'TRIGGER',
  CONDITION = 'CONDITION',
  DELAY = 'DELAY',
  ACTION = 'ACTION',
  NOTIFICATION = 'NOTIFICATION',
  PAYMENT = 'PAYMENT',
  WEBHOOK = 'WEBHOOK',
  PROVIDER_CALL = 'PROVIDER_CALL',
  APPROVAL = 'APPROVAL',
  BRANCH = 'BRANCH',
  PARALLEL = 'PARALLEL',
  END = 'END',
}

/**
 * Workflow Step Definition
 */
export interface WorkflowStep {
  stepId: string;
  name: string;
  type: WorkflowStepType;
  config: Record<string, any>;
  onSuccess?: string; // Next stepId
  onFailure?: string; // Fallback / dead-letter stepId
  compensationStepId?: string; // Step to execute if subsequent failure requires rollback
  timeoutMs?: number;
  maxRetries?: number;
}

/**
 * Declarative Workflow Definition Template
 */
export interface WorkflowDefinition {
  workflowId: string;
  name: string;
  description: string;
  version: number;
  triggerEvent: DomainEventType | string;
  status: WorkflowStatus;
  steps: WorkflowStep[];
  startStepId: string;
  tenantScope?: {
    level: 'PLATFORM' | 'VENDOR' | 'BRANCH';
    scopeId?: string;
  };
  createdAt: string;
  updatedAt: string;
}

/**
 * Workflow Execution Instance
 */
export interface WorkflowExecution {
  executionId: string;
  workflowId: string;
  version: number;
  correlationId: string;
  causationId?: string;
  status: WorkflowExecutionStatus;
  currentStepId?: string;
  contextData: Record<string, any>;
  stepHistory: Array<{
    stepId: string;
    stepName: string;
    type: WorkflowStepType;
    status: 'SUCCESS' | 'FAILED' | 'SKIPPED' | 'WAITING';
    startedAt: string;
    completedAt?: string;
    output?: any;
    error?: string;
  }>;
  retryCount: number;
  error?: {
    code: string;
    message: string;
    classification?: string;
    failedStepId?: string;
  };
  startedAt: string;
  completedAt?: string;
}

/**
 * Automation Rule Engine Types
 */
export enum RuleOperator {
  EQUALS = 'EQUALS',
  NOT_EQUALS = 'NOT_EQUALS',
  GREATER_THAN = 'GREATER_THAN',
  LESS_THAN = 'LESS_THAN',
  CONTAINS = 'CONTAINS',
  IN = 'IN',
  EXISTS = 'EXISTS',
  DATE_COMPARISON = 'DATE_COMPARISON',
  RELATIVE_DATE = 'RELATIVE_DATE',
}

export interface RulePredicate {
  field: string;
  operator: RuleOperator;
  value: any;
  logic?: 'AND' | 'OR' | 'NOT';
  nestedPredicates?: RulePredicate[];
}

export enum RuleActionType {
  SEND_NOTIFICATION = 'SEND_NOTIFICATION',
  CALL_INTEGRATION = 'CALL_INTEGRATION',
  TRIGGER_WORKFLOW = 'TRIGGER_WORKFLOW',
  CREATE_TASK = 'CREATE_TASK',
  UPDATE_ENTITY = 'UPDATE_ENTITY',
}

export interface RuleAction {
  actionType: RuleActionType;
  config: Record<string, any>;
}

export interface AutomationRule {
  ruleId: string;
  name: string;
  description?: string;
  triggerEvent: DomainEventType | string;
  predicates: RulePredicate[];
  actions: RuleAction[];
  isEnabled: boolean;
  priority: number;
  tenantScope?: {
    level: 'PLATFORM' | 'VENDOR' | 'BRANCH';
    scopeId?: string;
  };
  createdAt: string;
  updatedAt: string;
}

/**
 * Human-in-the-Loop Approval Types
 */
export enum ApprovalStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  ESCALATED = 'ESCALATED',
  TIMEOUT = 'TIMEOUT',
}

export interface ApprovalStep {
  stepIndex: number;
  title: string;
  approverRole: Role | string;
  approverUserId?: string;
  status: ApprovalStatus;
  decidedBy?: string;
  decisionNote?: string;
  decidedAt?: string;
}

export interface ApprovalRequest {
  requestId: string;
  definitionType: 'VENDOR_ONBOARDING' | 'LARGE_REFUND' | 'DAMAGE_CLAIM_PAYOUT' | 'VEHICLE_RETIREMENT' | 'MANUAL_OVERRIDE';
  entityType: string;
  entityId: string;
  requestedBy: {
    id: string;
    role: string;
  };
  currentStepIndex: number;
  steps: ApprovalStep[];
  overallStatus: ApprovalStatus;
  metadata: Record<string, any>;
  timeoutAt?: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Scheduling Engine Types
 */
export enum ScheduleType {
  ONE_TIME = 'ONE_TIME',
  RECURRING = 'RECURRING',
  CRON = 'CRON',
}

export interface ScheduledJob {
  jobId: string;
  name: string;
  scheduleType: ScheduleType;
  cronExpression?: string;
  scheduledTime: string;
  payload: Record<string, any>;
  actionType: string;
  status: 'SCHEDULED' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'CANCELLED';
  timezone: string;
  retryCount: number;
  maxRetries: number;
  createdAt: string;
  lastExecutedAt?: string;
}

/**
 * Customer Communication Profile & Preferences
 */
export interface CustomerCommunicationProfile {
  userId: string;
  preferredChannel: 'WHATSAPP' | 'SMS' | 'EMAIL' | 'PUSH';
  preferredLanguage: string; // e.g. 'en', 'hi', 'te', 'ta'
  channelSuccessRates: Record<string, number>; // channel -> score 0.0-1.0
  optedOutChannels: string[];
  bestSendTimeWindow?: {
    startHour: number;
    endHour: number;
  };
  deliveryFailureCount: Record<string, number>;
  lastUpdated: string;
}

/**
 * Unified Cross-Domain Operational Timeline Tracing
 */
export interface CorrelationTimelineEntry {
  traceId: string;
  correlationId: string;
  timestamp: string;
  sourceDomain: 'CUSTOMER' | 'BOOKINGS' | 'PAYMENTS' | 'FLEET' | 'INTEGRATIONS' | 'WORKFLOW' | 'NOTIFICATIONS' | 'APPROVAL';
  activity: string;
  status: 'SUCCESS' | 'WARNING' | 'FAILED' | 'INFO';
  details?: Record<string, any>;
}
