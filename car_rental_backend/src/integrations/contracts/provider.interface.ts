import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  TestConnectionResult,
} from '../registry/provider.types';

export interface BaseProvider {
  getProviderId(): string;
  getCategory(): IntegrationCategory;
  getDisplayName(): string;
  getSupportedCapabilities(): string[];
  hasCapability(capability: string): boolean;
  checkHealth?(): Promise<ProviderHealthCheckResult>;
  healthCheck?(): Promise<ProviderHealthCheckResult>;
  testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult>;
  getDefaultTimeoutMs(): number;
}
