import { IntegrationCategory } from '../registry/provider.types';

export type HierarchicalLevel = 'PLATFORM' | 'VENDOR' | 'BRANCH';

export interface IntegrationProviderConfig {
  providerId: string;
  category: IntegrationCategory;
  isEnabled: boolean;
  priority: number;
  credentials: Record<string, string>; // Encrypted at rest in DB
  settings: Record<string, any>;
  version?: number;
  updatedAt?: Date;
  updatedBy?: string;
}

export interface CategoryActiveProviderConfig {
  category: IntegrationCategory;
  activeProviderId: string;
  fallbackProviderId?: string;
  allowVendorOverride: boolean;
}

export interface ResolvedProviderConfig {
  providerId: string;
  category: IntegrationCategory;
  isEnabled: boolean;
  credentials: Record<string, string>; // Decrypted for internal provider execution
  settings: Record<string, any>;
  resolvedLevel: HierarchicalLevel;
  resolvedEntityId?: string;
}
