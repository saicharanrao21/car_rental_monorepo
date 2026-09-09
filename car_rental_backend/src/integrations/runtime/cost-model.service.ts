import { Injectable, Logger } from '@nestjs/common';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderCostModel } from './runtime.types';

@Injectable()
export class CostModelService {
  private readonly logger = new Logger(CostModelService.name);
  private readonly costModels = new Map<string, ProviderCostModel>();

  constructor() {
    this.seedDefaultCostModels();
  }

  private getKey(category: IntegrationCategory, providerId: string): string {
    return `${category}:${providerId}`.toLowerCase();
  }

  private seedDefaultCostModels(): void {
    // Standard default economics
    const defaults: ProviderCostModel[] = [
      {
        providerId: 'razorpay',
        category: IntegrationCategory.PAYMENT,
        fixedFee: 0,
        percentageFee: 0.02, // 2.0%
        perRequestCost: 0,
        perMessageCost: 0,
        currency: 'INR',
        regionSpecificCosts: { IN: 0.02, AE: 0.03 },
      },
      {
        providerId: 'stripe',
        category: IntegrationCategory.PAYMENT,
        fixedFee: 0.3,
        percentageFee: 0.029, // 2.9% + $0.30
        perRequestCost: 0,
        perMessageCost: 0,
        currency: 'USD',
        regionSpecificCosts: { US: 0.029, IN: 0.035, EU: 0.025 },
      },
      {
        providerId: 'cashfree',
        category: IntegrationCategory.PAYMENT,
        fixedFee: 0,
        percentageFee: 0.019, // 1.9%
        perRequestCost: 0,
        perMessageCost: 0,
        currency: 'INR',
        regionSpecificCosts: { IN: 0.019 },
      },
      {
        providerId: 'meta',
        category: IntegrationCategory.MESSAGING_WHATSAPP,
        fixedFee: 0,
        percentageFee: 0,
        perRequestCost: 0,
        perMessageCost: 0.45, // ~0.45 INR per template
        currency: 'INR',
        regionSpecificCosts: { IN: 0.45, AE: 1.2 },
      },
      {
        providerId: 'msg91',
        category: IntegrationCategory.MESSAGING_SMS,
        fixedFee: 0,
        percentageFee: 0,
        perRequestCost: 0,
        perMessageCost: 0.18, // 0.18 INR per SMS
        currency: 'INR',
        regionSpecificCosts: { IN: 0.18 },
      },
    ];

    for (const m of defaults) {
      this.costModels.set(this.getKey(m.category, m.providerId), m);
    }
  }

  setCostModel(model: ProviderCostModel): void {
    this.costModels.set(this.getKey(model.category, model.providerId), model);
    this.costModels.set(model.providerId.toLowerCase(), model);
  }

  registerCostModel(model: ProviderCostModel): void {
    this.setCostModel(model);
  }

  getCostModel(category: IntegrationCategory, providerId: string): ProviderCostModel | undefined {
    return this.costModels.get(this.getKey(category, providerId));
  }

  /**
   * Estimates cost for provider routing.
   */
  estimateCost(
    providerId: string,
    amount = 0,
    currency?: string,
    region?: string,
  ): number {
    let model = this.costModels.get(providerId.toLowerCase());
    if (!model) {
      for (const m of this.costModels.values()) {
        if (m.providerId.toLowerCase() === providerId.toLowerCase()) {
          model = m;
          break;
        }
      }
    }
    if (!model) return 0;

    let percentage = model.percentageFee;
    if (percentage > 1) {
      percentage = percentage / 100; // convert 2.0% to 0.02
    }
    if (region && model.regionSpecificCosts[region.toUpperCase()] !== undefined) {
      percentage = model.regionSpecificCosts[region.toUpperCase()];
      if (percentage > 1) percentage = percentage / 100;
    }

    const variableFee = amount * percentage;
    const baseFee = model.fixedFee + model.perRequestCost + model.perMessageCost;

    return Number((baseFee + variableFee).toFixed(4));
  }

  /**
   * Calculates the estimated cost of an operation for a provider.
   */
  calculateEstimatedCost(
    category: IntegrationCategory,
    providerId: string,
    amount = 0,
    region?: string,
  ): number {
    return this.estimateCost(providerId, amount, undefined, region);
  }
}
