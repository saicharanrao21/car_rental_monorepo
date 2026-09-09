import { IntegrationCategory } from '../registry/provider.types';

export interface ScoringWeights {
  healthWeight: number; // e.g. 0.25
  reliabilityWeight: number; // e.g. 0.20
  latencyWeight: number; // e.g. 0.15
  capabilityWeight: number; // e.g. 0.15
  regionalWeight: number; // e.g. 0.10
  costWeight: number; // e.g. 0.05
  priorityWeight: number; // e.g. 0.10
}

export interface ProviderScoreBreakdown {
  providerId: string;
  category: IntegrationCategory;
  finalScore: number; // 0 to 100
  rawFactors: {
    healthScore: number; // 0-100
    reliabilityScore: number; // 0-100
    latencyScore: number; // 0-100
    capabilityScore: number; // 0-100
    regionalScore: number; // 0-100
    costScore: number; // 0-100
    priorityScore: number; // 0-100
  };
  penalties: {
    incidentPenalty: number;
    rateLimitPenalty: number;
    circuitOpenPenalty: number;
  };
  weightedSum: number;
  explanation: string;
  evaluatedAt: string;
}

export interface ScoringContext {
  category: IntegrationCategory;
  requiredCapabilities?: string[];
  preferredCapabilities?: string[];
  country?: string;
  region?: string;
  currency?: string;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  maxAcceptableLatencyMs?: number;
}
