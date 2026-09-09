import { Injectable } from '@nestjs/common';
import {
  AccountingProvider,
  AccountingCapability,
  NormalizedAccountingInvoice,
  NormalizedAccountingPayout,
} from '../../contracts/accounting-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockAccountingAdapter implements AccountingProvider {
  getProviderId(): string {
    return 'mock_accounting';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.ACCOUNTING;
  }

  getDisplayName(): string {
    return 'Mock Accounting & Invoicing Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      AccountingCapability.SYNC_INVOICE,
      AccountingCapability.SYNC_CREDIT_NOTE,
      AccountingCapability.SYNC_PAYOUT,
      AccountingCapability.RECONCILE_ACCOUNTS,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 3000;
  }

  async syncInvoice(invoice: NormalizedAccountingInvoice): Promise<{ success: boolean; externalId?: string }> {
    return {
      success: true,
      externalId: `ext_inv_${invoice.invoiceNumber}`,
    };
  }

  async syncPayout(payout: NormalizedAccountingPayout): Promise<{ success: boolean; externalId?: string }> {
    return {
      success: true,
      externalId: `ext_payout_${payout.payoutId}`,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Accounting is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock Accounting connection test successful',
    };
  }
}
