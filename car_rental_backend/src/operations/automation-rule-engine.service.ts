import { Injectable, Logger, OnModuleInit, NotFoundException } from '@nestjs/common';
import {
  AutomationRule,
  DomainEvent,
  DomainEventType,
  RuleAction,
  RuleActionType,
  RuleOperator,
  RulePredicate,
} from './operations-domain.types';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';
import { CommunicationIntelligenceService } from './communication-intelligence.service';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';

@Injectable()
export class AutomationRuleEngineService implements OnModuleInit {
  private readonly logger = new Logger(AutomationRuleEngineService.name);

  // In-memory rules registry: ruleId -> AutomationRule
  private readonly rules = new Map<string, AutomationRule>();

  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly auditTracer: OperationsAuditTracerService,
    private readonly commIntelligence: CommunicationIntelligenceService,
    private readonly integrationRuntime: IntegrationRuntimeService,
  ) {}

  onModuleInit() {
    this.seedDefaultRules();

    // Listen to all domain events globally and evaluate against active automation rules
    this.eventBus.subscribeGlobal('automation-rule-evaluator', async (event: DomainEvent) => {
      await this.evaluateRulesForEvent(event);
    });
  }

  /**
   * Register or update an automation rule.
   */
  public registerRule(rule: AutomationRule): AutomationRule {
    this.rules.set(rule.ruleId, rule);
    this.logger.log(`[RULE_REGISTERED] Automation Rule ${rule.ruleId} (${rule.name}) registered.`);
    return rule;
  }

  /**
   * Get single rule by ID.
   */
  public getRule(ruleId: string): AutomationRule {
    const rule = this.rules.get(ruleId);
    if (!rule) {
      throw new NotFoundException(`Automation rule ${ruleId} not found`);
    }
    return rule;
  }

  /**
   * List rules with optional filters.
   */
  public listRules(filter?: { triggerEvent?: string; isEnabled?: boolean }): AutomationRule[] {
    let list = Array.from(this.rules.values());
    if (filter?.triggerEvent) {
      list = list.filter((r) => r.triggerEvent === filter.triggerEvent);
    }
    if (filter?.isEnabled !== undefined) {
      list = list.filter((r) => r.isEnabled === filter.isEnabled);
    }
    return list.sort((a, b) => b.priority - a.priority);
  }

  /**
   * Delete or deactivate rule.
   */
  public deleteRule(ruleId: string): boolean {
    if (!this.rules.has(ruleId)) {
      throw new NotFoundException(`Rule ${ruleId} not found`);
    }
    return this.rules.delete(ruleId);
  }

  /**
   * Evaluate all matching enabled rules against a domain event.
   */
  public async evaluateRulesForEvent(event: DomainEvent): Promise<number> {
    const candidateRules = Array.from(this.rules.values())
      .filter((r) => r.isEnabled && r.triggerEvent === event.eventType)
      .sort((a, b) => b.priority - a.priority);

    let executedCount = 0;

    for (const rule of candidateRules) {
      // Check tenant scope if applicable
      if (rule.tenantScope && rule.tenantScope.scopeId) {
        const eventScopeId =
          rule.tenantScope.level === 'VENDOR'
            ? event.tenantContext?.vendorId
            : event.tenantContext?.branchId;
        if (eventScopeId && eventScopeId !== rule.tenantScope.scopeId) {
          continue; // Rule does not apply to this tenant
        }
      }

      const isMatch = this.evaluatePredicates(rule.predicates, event);
      if (isMatch) {
        this.logger.log(`[RULE_MATCH] Event ${event.eventType} matched Rule ${rule.ruleId} (${rule.name})`);
        await this.executeRuleActions(rule, event);
        executedCount++;
      }
    }

    return executedCount;
  }

  /**
   * Recursive predicate tree evaluator with AND/OR/NOT support.
   */
  public evaluatePredicates(predicates: RulePredicate[], event: DomainEvent): boolean {
    if (!predicates || predicates.length === 0) return true;

    for (const pred of predicates) {
      const fieldVal = this.extractFieldValue(event, pred.field);
      const conditionPassed = this.checkSinglePredicate(pred, fieldVal);

      // Evaluate nested predicates if any
      let nestedPassed = true;
      if (pred.nestedPredicates && pred.nestedPredicates.length > 0) {
        nestedPassed = this.evaluatePredicates(pred.nestedPredicates, event);
      }

      const totalPassed = conditionPassed && nestedPassed;

      if (pred.logic === 'OR') {
        if (totalPassed) return true;
      } else if (pred.logic === 'NOT') {
        if (totalPassed) return false;
      } else {
        // Default: AND
        if (!totalPassed) return false;
      }
    }

    return true;
  }

  private checkSinglePredicate(pred: RulePredicate, actualValue: any): boolean {
    switch (pred.operator) {
      case RuleOperator.EQUALS:
        return actualValue === pred.value;

      case RuleOperator.NOT_EQUALS:
        return actualValue !== pred.value;

      case RuleOperator.GREATER_THAN:
        return Number(actualValue) > Number(pred.value);

      case RuleOperator.LESS_THAN:
        return Number(actualValue) < Number(pred.value);

      case RuleOperator.CONTAINS:
        if (typeof actualValue === 'string') return actualValue.includes(pred.value);
        if (Array.isArray(actualValue)) return actualValue.includes(pred.value);
        return false;

      case RuleOperator.IN:
        if (Array.isArray(pred.value)) return pred.value.includes(actualValue);
        return false;

      case RuleOperator.EXISTS:
        return actualValue !== undefined && actualValue !== null;

      case RuleOperator.DATE_COMPARISON: {
        const actualDate = new Date(actualValue).getTime();
        const targetDate = new Date(pred.value).getTime();
        return actualDate <= targetDate;
      }

      case RuleOperator.RELATIVE_DATE: {
        // pred.value example: "+24h", "-7d"
        const hoursOffset = this.parseRelativeOffsetHours(pred.value);
        const targetTimestamp = Date.now() + hoursOffset * 60 * 60 * 1000;
        const actualTimestamp = new Date(actualValue).getTime();
        return Math.abs(actualTimestamp - targetTimestamp) <= 24 * 60 * 60 * 1000;
      }

      default:
        return false;
    }
  }

  private parseRelativeOffsetHours(offsetStr: string): number {
    if (!offsetStr) return 0;
    const match = offsetStr.match(/([+-]?\d+)([hd])/);
    if (!match) return 0;
    const num = parseInt(match[1], 10);
    const unit = match[2];
    return unit === 'd' ? num * 24 : num;
  }

  /**
   * Execute actions associated with the matched rule.
   */
  private async executeRuleActions(rule: AutomationRule, event: DomainEvent): Promise<void> {
    for (const action of rule.actions) {
      this.logger.debug(`[RULE_ACTION] Executing ${action.actionType} for rule ${rule.ruleId}`);

      try {
        switch (action.actionType) {
          case RuleActionType.SEND_NOTIFICATION: {
            const userId = event.payload?.userId || event.actor?.id || 'system';
            const channels = this.commIntelligence.resolveChannelChain(userId);
            const primaryChannel = channels[0] || 'WHATSAPP';

            this.logger.log(
              `[NOTIFICATION_DISPATCH] Dispatching ${primaryChannel} to user ${userId} for rule ${rule.ruleId}`,
            );

            // Dispatch via IntegrationRuntime
            try {
              await this.integrationRuntime.execute({
                category: this.getMessagingCategory(primaryChannel),
                capability: primaryChannel.toLowerCase(),
                payload: {
                  to: event.payload?.phone || event.payload?.email || userId,
                  message: action.config.template || `Automated alert for ${rule.name}`,
                  metadata: action.config,
                },
                metadata: { correlationId: event.correlationId },
              });
              this.commIntelligence.recordDeliverySuccess(userId, primaryChannel);
            } catch (err: any) {
              this.logger.warn(`Primary channel ${primaryChannel} failed: ${err.message}. Trying fallback.`);
              this.commIntelligence.recordDeliveryFailure(userId, primaryChannel);
              // Fallback to secondary channel if available
              if (channels.length > 1) {
                const fallbackChannel = channels[1];
                this.logger.log(`[CHANNEL_FALLBACK] Falling back to ${fallbackChannel}`);
                await this.integrationRuntime.execute({
                  category: this.getMessagingCategory(fallbackChannel),
                  capability: fallbackChannel.toLowerCase(),
                  payload: {
                    to: event.payload?.phone || event.payload?.email || userId,
                    message: action.config.template || `Automated alert for ${rule.name}`,
                  },
                  metadata: { correlationId: event.correlationId },
                });
              }
            }
            break;
          }

          case RuleActionType.CALL_INTEGRATION: {
            await this.integrationRuntime.execute({
              category: action.config.category || IntegrationCategory.PAYMENT,
              capability: action.config.capability || 'verify',
              preferredProviderId: action.config.providerId,
              payload: { ...action.config.payload, ...event.payload },
              metadata: { correlationId: event.correlationId },
            });
            break;
          }

          case RuleActionType.TRIGGER_WORKFLOW: {
            // Emits an event to trigger workflow
            this.logger.log(`[RULE_TRIGGER_WORKFLOW] Triggering workflow ${action.config.workflowId}`);
            await this.eventBus.emit({
              eventType: action.config.triggerEvent || DomainEventType.BOOKING_CREATED,
              aggregateType: event.aggregateType,
              aggregateId: event.aggregateId,
              payload: event.payload,
              correlationId: event.correlationId,
              causationId: event.eventId,
            });
            break;
          }

          case RuleActionType.CREATE_TASK: {
            this.logger.log(`[TASK_CREATED] Automation task created: ${action.config.taskName}`);
            break;
          }

          case RuleActionType.UPDATE_ENTITY: {
            this.logger.log(`[ENTITY_UPDATED] Automation entity updated: ${action.config.entity}`);
            break;
          }
        }

        this.auditTracer.recordActivity({
          correlationId: event.correlationId,
          sourceDomain: 'WORKFLOW',
          activity: `Rule executed: ${rule.name} -> ${action.actionType}`,
          status: 'SUCCESS',
          details: { ruleId: rule.ruleId, actionType: action.actionType },
        });
      } catch (err: any) {
        this.logger.error(`Error executing action ${action.actionType} in rule ${rule.ruleId}: ${err.message}`);
        this.auditTracer.recordActivity({
          correlationId: event.correlationId,
          sourceDomain: 'WORKFLOW',
          activity: `Rule action FAILED: ${rule.name} -> ${action.actionType}`,
          status: 'FAILED',
          details: { ruleId: rule.ruleId, error: err.message },
        });
      }
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

  private extractFieldValue(obj: any, path: string): any {
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
   * Standard enterprise automation rules
   */
  private seedDefaultRules(): void {
    // 1. 24h Booking Reminder Rule
    this.registerRule({
      ruleId: 'RULE_BOOKING_24H_REMINDER',
      name: 'Send 24-Hour Pre-Pickup Reminder',
      description: 'Sends WhatsApp reminder and push notification if pickup is scheduled within 24 hours.',
      triggerEvent: DomainEventType.BOOKING_CONFIRMED,
      predicates: [
        {
          field: 'payload.bookingStatus',
          operator: RuleOperator.EQUALS,
          value: 'CONFIRMED',
          logic: 'AND',
        },
      ],
      actions: [
        {
          actionType: RuleActionType.SEND_NOTIFICATION,
          config: { template: 'Your DriveGo rental starts in 24 hours! Tap here for pickup directions.' },
        },
      ],
      isEnabled: true,
      priority: 10,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 2. Payment Failure Customer Care Task
    this.registerRule({
      ruleId: 'RULE_PAYMENT_FAILURE_ALERT',
      name: 'Escalate Failed Payment to Support',
      description: 'Alerts customer via WhatsApp fallback and generates an operational task.',
      triggerEvent: DomainEventType.PAYMENT_FAILED,
      predicates: [
        {
          field: 'payload.amount',
          operator: RuleOperator.GREATER_THAN,
          value: 0,
          logic: 'AND',
        },
      ],
      actions: [
        {
          actionType: RuleActionType.SEND_NOTIFICATION,
          config: { template: 'Your payment attempt did not go through. Please click here to retry.' },
        },
        {
          actionType: RuleActionType.CREATE_TASK,
          config: { taskName: 'Investigate payment failure for rental recovery' },
        },
      ],
      isEnabled: true,
      priority: 20,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    // 3. Document Expiry Alert
    this.registerRule({
      ruleId: 'RULE_DOC_EXPIRY_ALERT',
      name: 'Document Expiration 30-Day Notice',
      description: 'Notifies vendor and creates compliance task when vehicle insurance or permit is expiring.',
      triggerEvent: DomainEventType.DOCUMENT_EXPIRING,
      predicates: [
        {
          field: 'payload.daysRemaining',
          operator: RuleOperator.LESS_THAN,
          value: 30,
          logic: 'AND',
        },
      ],
      actions: [
        {
          actionType: RuleActionType.SEND_NOTIFICATION,
          config: { template: 'Compliance Alert: Vehicle document expires in less than 30 days.' },
        },
        {
          actionType: RuleActionType.CREATE_TASK,
          config: { taskName: 'Renew vehicle document before expiry date' },
        },
      ],
      isEnabled: true,
      priority: 15,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }
}
