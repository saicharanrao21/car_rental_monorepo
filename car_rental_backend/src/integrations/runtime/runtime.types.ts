import { IntegrationCategory, IntegrationContext } from '../registry/provider.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';

export enum RoutingStrategy {
  PRIMARY = 'PRIMARY',
  PRIORITY = 'PRIORITY',
  ROUND_ROBIN = 'ROUND_ROBIN',
  WEIGHTED = 'WEIGHTED',
  LEAST_LATENCY = 'LEAST_LATENCY',
  HEALTH_BASED = 'HEALTH_BASED',
  REGION_BASED = 'REGION_BASED',
  CURRENCY_BASED = 'CURRENCY_BASED',
  CAPABILITY_BASED = 'CAPABILITY_BASED',
  COST_OPTIMIZED = 'COST_OPTIMIZED',
  SCORE_OPTIMIZED = 'SCORE_OPTIMIZED',
  CUSTOM_RULE = 'CUSTOM_RULE',
}

export enum FailureClassification {
  TRANSIENT = 'TRANSIENT',
  RATE_LIMITED = 'RATE_LIMITED',
  TIMEOUT = 'TIMEOUT',
  NETWORK = 'NETWORK',
  AUTHENTICATION = 'AUTHENTICATION',
  INVALID_REQUEST = 'INVALID_REQUEST',
  PROVIDER_DECLINED = 'PROVIDER_DECLINED',
  DUPLICATE = 'DUPLICATE',
  NOT_SUPPORTED = 'NOT_SUPPORTED',
  CONFIGURATION = 'CONFIGURATION',
  PERMANENT = 'PERMANENT',
}

export enum CircuitState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN',
}

export enum SimulationScenario {
  NONE = 'NONE',
  SUCCESS = 'SUCCESS',
  TIMEOUT = 'TIMEOUT',
  NETWORK_FAILURE = 'NETWORK_FAILURE',
  AUTH_FAILURE = 'AUTH_FAILURE',
  AUTH_401 = 'AUTH_401',
  FORBIDDEN_403 = 'FORBIDDEN_403',
  RATE_LIMIT = 'RATE_LIMIT',
  RATE_LIMIT_429 = 'RATE_LIMIT_429',
  PROVIDER_DECLINED = 'PROVIDER_DECLINED',
  SLOW_RESPONSE = 'SLOW_RESPONSE',
  MALFORMED_RESPONSE = 'MALFORMED_RESPONSE',
  INVALID_REQUEST = 'INVALID_REQUEST',
  DUPLICATE = 'DUPLICATE',
  NOT_SUPPORTED = 'NOT_SUPPORTED',
  CONFIGURATION_FAILURE = 'CONFIGURATION_FAILURE',
  WEBHOOK_FAILURE = 'WEBHOOK_FAILURE',
  WEBHOOK_SIGNATURE_MISMATCH = 'WEBHOOK_SIGNATURE_MISMATCH',
  LATENCY_INJECTION = 'LATENCY_INJECTION',
  PARTIAL_FAILURE = 'PARTIAL_FAILURE',
}

export interface CircuitBreakerConfig {
  failureThreshold: number; // consecutive or windowed failures
  rollingWindowMs: number; // e.g. 60,000ms
  openDurationMs: number; // cooldown e.g. 30,000ms
  halfOpenProbes: number; // number of trial requests
  successThreshold: number; // consecutive successes needed in half-open to close
  timeoutThresholdMs: number;
}

export interface RateLimitConfig {
  rps: number;
  rpm: number;
  burstCapacity: number;
  concurrencyLimit: number;
}

export interface CostTierRate {
  minVolume: number;
  maxVolume?: number;
  percentageFee: number;
  fixedFee: number;
}

export interface ProviderCostModel {
  providerId: string;
  category: IntegrationCategory;
  fixedFee: number;
  percentageFee: number;
  perRequestCost: number;
  perMessageCost: number;
  perGbCost?: number;
  minimumCharge?: number;
  tierRates?: CostTierRate[];
  currency: string;
  regionSpecificCosts: Record<string, number>;
}

export interface ProviderPolicyRule {
  id: string;
  name: string;
  enabled: boolean;
  priority: number;
  conditions: {
    category?: IntegrationCategory;
    region?: string;
    currency?: string;
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
    capabilities?: string[];
    maxLatencyMs?: number;
  };
  actions: {
    preferredProviderId?: string;
    allowedProviders?: string[];
    deniedProviders?: string[];
    routingStrategy?: RoutingStrategy;
    forceFallback?: boolean;
  };
}

export interface IntegrationExecutionRequest<TInput = any> {
  category: IntegrationCategory;
  capability: string;
  payload: TInput;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  region?: string;
  currency?: string;
  environment?: ProviderEnvironment;
  idempotencyKey?: string;
  preferredProviderId?: string;
  routingStrategy?: RoutingStrategy;
  timeoutMs?: number;
  isIdempotent?: boolean;
  simulationScenario?: SimulationScenario;
  metadata?: Record<string, any>;
}

export interface IntegrationAttemptRecord {
  attemptNumber: number;
  providerId: string;
  status: 'SUCCESS' | 'FAILED' | 'RETRY' | 'CIRCUIT_OPEN' | 'RATE_LIMITED' | 'TIMEOUT';
  errorClassification?: FailureClassification;
  errorMessage?: string;
  latencyMs: number;
  timestamp: Date;
}

export interface CandidateEvaluationExplanation {
  providerId: string;
  score: number;
  eligible: boolean;
  rejectionReason?: string;
  factorScores: {
    healthScore: number;
    latencyScore: number;
    costScore: number;
    capabilityScore: number;
    priorityScore: number;
    policyScore: number;
  };
}

export interface RoutingDecisionExplanation {
  selectedProviderId: string;
  strategyUsed: RoutingStrategy;
  reasons: string[];
  candidatesEvaluated: CandidateEvaluationExplanation[];
  fallbackChain: string[];
}

export interface IntegrationExecutionResult<TOutput = any> {
  success: boolean;
  data?: TOutput;
  error?: {
    code: string;
    message: string;
    classification: FailureClassification;
    providerId: string;
    details?: any;
  };
  providerId: string;
  category: IntegrationCategory;
  capability: string;
  environment: ProviderEnvironment;
  attempts: IntegrationAttemptRecord[];
  fallbackOccurred: boolean;
  latencyMs: number;
  correlationId: string;
  idempotencyKey?: string;
  explanation?: RoutingDecisionExplanation;
}

export interface ProviderRollingHealth {
  providerId: string;
  category: IntegrationCategory;
  successRate: number; // 0 to 100
  failureRate: number; // 0 to 100
  timeoutRate: number; // 0 to 100
  latencyP50: number;
  latencyP95: number;
  latencyP99: number;
  failureStreak: number;
  recoveryStreak: number;
  circuitState: CircuitState;
  lastSuccess?: Date | null;
  lastFailure?: Date | null;
  totalExecutions: number;
}
