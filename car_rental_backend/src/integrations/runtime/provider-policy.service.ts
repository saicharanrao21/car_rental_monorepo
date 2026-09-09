import { Injectable, Logger } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderPolicyRule, RoutingStrategy } from './runtime.types';

export interface EvaluatedPolicyResult {
  preferredProviderId?: string;
  allowedProviders?: string[];
  deniedProviders: string[];
  routingStrategyOverride?: RoutingStrategy;
  overrideStrategy?: RoutingStrategy;
  forceFallback?: boolean;
}

export interface PolicyEvaluationContext {
  category?: IntegrationCategory;
  region?: string;
  currency?: string;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  capabilities?: string[];
  currentLatencyMs?: number;
  maxLatencyMs?: number;
}

@Injectable()
export class ProviderPolicyService {
  private readonly logger = new Logger(ProviderPolicyService.name);
  private readonly rules = new Map<string, ProviderPolicyRule>();

  constructor() {
    this.seedDefaultPolicies();
  }

  private seedDefaultPolicies(): void {
    // Example default policies
    this.registerPolicy({
      id: 'policy_inr_upi_preference',
      name: 'Prefer Indian Domestic Gateways for INR',
      enabled: true,
      priority: 10,
      conditions: {
        category: IntegrationCategory.PAYMENT,
        currency: 'INR',
      },
      actions: {
        preferredProviderId: 'razorpay',
      },
    });
  }

  public registerPolicy(rule: ProviderPolicyRule): void {
    this.rules.set(rule.id, { ...rule });
  }

  public addRule(rule: ProviderPolicyRule): void {
    this.registerPolicy(rule);
  }

  public deletePolicy(id: string): void {
    this.rules.delete(id);
  }

  public removeRule(id: string): void {
    this.deletePolicy(id);
  }

  public getPolicies(): ProviderPolicyRule[] {
    return Array.from(this.rules.values()).sort((a, b) => a.priority - b.priority);
  }

  public getAllRules(): ProviderPolicyRule[] {
    return this.getPolicies();
  }

  public clearPolicies(): void {
    this.rules.clear();
  }

  /**
   * Evaluates all policies matching given context.
   */
  public evaluatePolicies(context: PolicyEvaluationContext): EvaluatedPolicyResult {
    const result: EvaluatedPolicyResult = {
      deniedProviders: [],
    };
    const deniedSet = new Set<string>();

    const sortedRules = this.getPolicies();

    for (const rule of sortedRules) {
      if (!rule.enabled) continue;
      const c = rule.conditions;

      if (c.category && context.category && c.category !== context.category) continue;
      if (c.region && context.region && c.region.toUpperCase() !== context.region.toUpperCase()) continue;
      if (c.currency && context.currency && c.currency.toUpperCase() !== context.currency.toUpperCase()) continue;
      if (c.vendorId && context.vendorId && c.vendorId !== context.vendorId) continue;
      if (c.branchId && context.branchId && c.branchId !== context.branchId) continue;

      if (c.capabilities && context.capabilities && context.capabilities.length > 0) {
        const hasAll = c.capabilities.every((cap) =>
          context.capabilities!.some((ctxCap) => ctxCap.toLowerCase() === cap.toLowerCase()),
        );
        if (!hasAll) continue;
      }

      if (c.maxLatencyMs && context.currentLatencyMs && context.currentLatencyMs <= c.maxLatencyMs) {
        continue;
      }

      // Action applications
      if (rule.actions.deniedProviders) {
        for (const denied of rule.actions.deniedProviders) {
          deniedSet.add(denied.toLowerCase());
        }
      }

      if (rule.actions.allowedProviders) {
        result.allowedProviders = rule.actions.allowedProviders.map((p) => p.toLowerCase());
      }

      if (rule.actions.preferredProviderId) {
        result.preferredProviderId = rule.actions.preferredProviderId;
      }

      if (rule.actions.routingStrategy) {
        result.routingStrategyOverride = rule.actions.routingStrategy;
        result.overrideStrategy = rule.actions.routingStrategy;
      }

      if (rule.actions.forceFallback) {
        result.forceFallback = true;
      }
    }

    result.deniedProviders = Array.from(deniedSet);
    return result;
  }

  public evaluate(
    category: IntegrationCategory,
    options?: Omit<PolicyEvaluationContext, 'category'>,
  ): EvaluatedPolicyResult {
    return this.evaluatePolicies({ category, ...options });
  }
}
