import { ProviderHealthStatus } from '../registry/provider.types';

export interface ProviderHealthRecord {
  providerId: string;
  category: string;
  status: ProviderHealthStatus;
  latencyMs: number;
  lastSuccessfulCheck: Date | null;
  lastFailedCheck: Date | null;
  lastErrorMessage: string | null;
  details?: Record<string, any>;
}

export interface TestConnectionRequest {
  category: string;
  providerId: string;
  credentials?: Record<string, string>;
}
