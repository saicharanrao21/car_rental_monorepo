import { Injectable, Logger } from '@nestjs/common';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../registry/provider.types';
import { BaseProvider } from '../contracts/provider.interface';
import { ProviderHealthRecord } from './provider-health.types';
import { CircuitState, FailureClassification, ProviderRollingHealth } from '../runtime/runtime.types';

interface HealthExecutionSample {
  timestamp: number;
  success: boolean;
  latencyMs: number;
  classification?: FailureClassification;
}

interface ProviderRollingStats {
  samples: HealthExecutionSample[];
  failureStreak: number;
  recoveryStreak: number;
  lastSuccess?: Date | null;
  lastFailure?: Date | null;
  rateLimitCount: number;
  authFailureCount: number;
}

@Injectable()
export class ProviderHealthService {
  private readonly logger = new Logger(ProviderHealthService.name);
  private readonly healthRecords = new Map<string, ProviderHealthRecord>();
  private readonly rollingStats = new Map<string, ProviderRollingStats>();
  private readonly MAX_SAMPLES = 200;

  private getRecordKey(category: string, providerId: string): string {
    return `${category}:${providerId}`.toLowerCase();
  }

  /**
   * Records the outcome of a provider health check.
   */
  recordHealth(
    category: IntegrationCategory,
    providerId: string,
    result: ProviderHealthCheckResult,
  ): ProviderHealthRecord {
    const key = this.getRecordKey(category, providerId);
    const existing = this.healthRecords.get(key);

    const isSuccess =
      result.status === ProviderHealthStatus.HEALTHY ||
      result.status === ProviderHealthStatus.ACTIVE ||
      result.status === ProviderHealthStatus.CONFIGURED;

    const record: ProviderHealthRecord = {
      providerId,
      category,
      status: result.status,
      latencyMs: result.latencyMs,
      lastSuccessfulCheck: isSuccess ? new Date() : existing?.lastSuccessfulCheck ?? null,
      lastFailedCheck: !isSuccess ? new Date() : existing?.lastFailedCheck ?? null,
      lastErrorMessage: !isSuccess ? result.message || 'Health check failed' : null,
      details: result.details,
    };

    this.healthRecords.set(key, record);
    return record;
  }

  /**
   * Retrieves the current health record for a provider.
   */
  getHealth(category: IntegrationCategory, providerId: string): ProviderHealthRecord {
    const key = this.getRecordKey(category, providerId);
    return (
      this.healthRecords.get(key) || {
        providerId,
        category,
        status: ProviderHealthStatus.CONFIGURED,
        latencyMs: 0,
        lastSuccessfulCheck: null,
        lastFailedCheck: null,
        lastErrorMessage: null,
      }
    );
  }

  /**
   * Records an execution outcome for rolling analytics.
   */
  recordExecutionOutcome(
    category: IntegrationCategory,
    providerId: string,
    outcome: {
      success: boolean;
      latencyMs: number;
      classification?: FailureClassification;
    },
  ): void {
    const key = this.getRecordKey(category, providerId);
    let stats = this.rollingStats.get(key);
    if (!stats) {
      stats = {
        samples: [],
        failureStreak: 0,
        recoveryStreak: 0,
        lastSuccess: null,
        lastFailure: null,
        rateLimitCount: 0,
        authFailureCount: 0,
      };
      this.rollingStats.set(key, stats);
    }

    const sample: HealthExecutionSample = {
      timestamp: Date.now(),
      success: outcome.success,
      latencyMs: Math.max(0, outcome.latencyMs),
      classification: outcome.classification,
    };

    stats.samples.push(sample);
    if (stats.samples.length > this.MAX_SAMPLES) {
      stats.samples.shift();
    }

    if (outcome.success) {
      stats.recoveryStreak += 1;
      stats.failureStreak = 0;
      stats.lastSuccess = new Date();
    } else {
      stats.failureStreak += 1;
      stats.recoveryStreak = 0;
      stats.lastFailure = new Date();
      if (outcome.classification === FailureClassification.RATE_LIMITED) {
        stats.rateLimitCount += 1;
      }
      if (outcome.classification === FailureClassification.AUTHENTICATION) {
        stats.authFailureCount += 1;
      }
    }
  }

  /**
   * Computes rolling health analytics (success rate, failure rate, timeout rate, p50/p95/p99 latency).
   */
  getRollingHealth(
    category: IntegrationCategory,
    providerId: string,
    circuitState: CircuitState = CircuitState.CLOSED,
  ): ProviderRollingHealth {
    const key = this.getRecordKey(category, providerId);
    const stats = this.rollingStats.get(key);

    if (!stats || stats.samples.length === 0) {
      return {
        providerId,
        category,
        successRate: 100,
        failureRate: 0,
        timeoutRate: 0,
        latencyP50: 0,
        latencyP95: 0,
        latencyP99: 0,
        failureStreak: 0,
        recoveryStreak: 0,
        circuitState,
        lastSuccess: null,
        lastFailure: null,
        totalExecutions: 0,
      };
    }

    const total = stats.samples.length;
    const successes = stats.samples.filter((s) => s.success).length;
    const timeouts = stats.samples.filter(
      (s) => s.classification === FailureClassification.TIMEOUT,
    ).length;
    const failures = total - successes;

    const latencies = stats.samples.map((s) => s.latencyMs).sort((a, b) => a - b);
    const p50Index = Math.min(latencies.length - 1, Math.floor(latencies.length * 0.5));
    const p95Index = Math.min(latencies.length - 1, Math.floor(latencies.length * 0.95));
    const p99Index = Math.min(latencies.length - 1, Math.floor(latencies.length * 0.99));

    return {
      providerId,
      category,
      successRate: Math.round((successes / total) * 100 * 10) / 10,
      failureRate: Math.round((failures / total) * 100 * 10) / 10,
      timeoutRate: Math.round((timeouts / total) * 100 * 10) / 10,
      latencyP50: latencies[p50Index] || 0,
      latencyP95: latencies[p95Index] || 0,
      latencyP99: latencies[p99Index] || 0,
      failureStreak: stats.failureStreak,
      recoveryStreak: stats.recoveryStreak,
      circuitState,
      lastSuccess: stats.lastSuccess,
      lastFailure: stats.lastFailure,
      totalExecutions: total,
    };
  }

  /**
   * Return rolling health for all known providers.
   */
  getAllRollingHealth(getCircuitState?: (providerId: string) => CircuitState): ProviderRollingHealth[] {
    const results: ProviderRollingHealth[] = [];
    for (const [key] of this.rollingStats.entries()) {
      const [category, providerId] = key.split(':');
      const cState = getCircuitState ? getCircuitState(providerId) : CircuitState.CLOSED;
      results.push(this.getRollingHealth(category as IntegrationCategory, providerId, cState));
    }
    return results;
  }

  /**
   * Tests connection to a live provider using supplied or configured credentials.
   */
  async testConnection(
    provider: BaseProvider,
    credentials?: Record<string, any>,
  ): Promise<TestConnectionResult> {
    const startTime = Date.now();
    try {
      this.logger.log(`[TEST_CONNECTION] Testing connection for ${provider.getCategory()}/${provider.getProviderId()}`);
      const result = await provider.testConnection(credentials);
      const latencyMs = Date.now() - startTime;

      const healthStatus = result.success
        ? ProviderHealthStatus.HEALTHY
        : ProviderHealthStatus.CREDENTIAL_FAILURE;

      this.recordHealth(provider.getCategory(), provider.getProviderId(), {
        status: healthStatus,
        latencyMs,
        message: result.message || result.error,
        lastChecked: new Date(),
        details: result.details,
      });

      this.recordExecutionOutcome(provider.getCategory(), provider.getProviderId(), {
        success: result.success,
        latencyMs,
        classification: result.success ? undefined : FailureClassification.AUTHENTICATION,
      });

      return {
        ...result,
        latencyMs,
      };
    } catch (err: any) {
      const latencyMs = Date.now() - startTime;
      this.logger.error(`[TEST_CONNECTION_FAILED] ${provider.getProviderId()}: ${err?.message}`);

      this.recordHealth(provider.getCategory(), provider.getProviderId(), {
        status: ProviderHealthStatus.UNAVAILABLE,
        latencyMs,
        message: err?.message || 'Connection test failed',
        lastChecked: new Date(),
      });

      this.recordExecutionOutcome(provider.getCategory(), provider.getProviderId(), {
        success: false,
        latencyMs,
        classification: FailureClassification.NETWORK,
      });

      return {
        success: false,
        latencyMs,
        error: err?.message || 'Test connection failed',
      };
    }
  }
}
