import { Injectable, Logger } from '@nestjs/common';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../registry/provider.types';
import { BaseProvider } from '../contracts/provider.interface';
import { ProviderHealthRecord } from './provider-health.types';

@Injectable()
export class ProviderHealthService {
  private readonly logger = new Logger(ProviderHealthService.name);
  private readonly healthRecords = new Map<string, ProviderHealthRecord>();

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

      return {
        success: false,
        latencyMs,
        error: err?.message || 'Test connection failed',
      };
    }
  }
}
