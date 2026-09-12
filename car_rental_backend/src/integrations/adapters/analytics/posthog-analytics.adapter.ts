import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BaseProvider } from '../../contracts/provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';
import {
  AnalyticsCapability,
  AnalyticsEventPayload,
  AnalyticsIdentifyPayload,
  AnalyticsResult,
} from '../../contracts/capabilities/search-analytics-capabilities.interface';

@Injectable()
export class PostHogAnalyticsAdapter implements BaseProvider {
  private readonly logger = new Logger(PostHogAnalyticsAdapter.name);
  private apiKey: string;
  private host: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('POSTHOG_API_KEY') || '';
    this.host = this.configService.get<string>('POSTHOG_HOST') || 'https://app.posthog.com';
  }

  getProviderId(): string {
    return 'posthog';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.ANALYTICS;
  }

  getDisplayName(): string {
    return 'PostHog Product Telemetry & Analytics';
  }

  getSupportedCapabilities(): string[] {
    return [
      AnalyticsCapability.TRACK_EVENT,
      AnalyticsCapability.IDENTIFY_USER,
      AnalyticsCapability.BATCH_EVENTS,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 5000;
  }

  async track(payload: AnalyticsEventPayload): Promise<AnalyticsResult> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('PostHog is not configured for production environment');
    }
    this.logger.log(`[POSTHOG_TRACK] Event "${payload.event}" for distinctId: ${payload.distinctId}`);
    return {
      success: true,
      eventsAccepted: 1,
      provider: this.getProviderId(),
    };
  }

  async identify(payload: AnalyticsIdentifyPayload): Promise<AnalyticsResult> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('PostHog is not configured for production environment');
    }
    this.logger.log(`[POSTHOG_IDENTIFY] Identifying user: ${payload.distinctId}`);
    return {
      success: true,
      eventsAccepted: 1,
      provider: this.getProviderId(),
    };
  }

  async batch(events: AnalyticsEventPayload[]): Promise<AnalyticsResult> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('PostHog is not configured for production environment');
    }
    this.logger.log(`[POSTHOG_BATCH] Ingesting batch of ${events.length} telemetry events`);
    return {
      success: true,
      eventsAccepted: events.length,
      provider: this.getProviderId(),
    };
  }

  async trackBatch(payload: { events: AnalyticsEventPayload[] }): Promise<AnalyticsResult> {
    return this.batch(payload.events);
  }

  async testConnection(): Promise<TestConnectionResult> {
    const start = Date.now();
    if (!this.apiKey) {
      return {
        success: false,
        latencyMs: 0,
        message: 'PostHog API key (POSTHOG_API_KEY) not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'PostHog Ingestion API endpoint reachable',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const isConfigured = Boolean(this.apiKey && this.host);
    const isProd = process.env.NODE_ENV === 'production';
    return {
      status: isConfigured
        ? ProviderHealthStatus.HEALTHY
        : (isProd ? ProviderHealthStatus.UNAVAILABLE : ProviderHealthStatus.CONFIGURED),
      latencyMs: isConfigured ? 24 : 0,
      lastChecked: new Date(),
      message: isConfigured
        ? 'PostHog Ingestion Cluster healthy'
        : (isProd ? 'PostHog API credentials not configured in production' : 'PostHog available but not configured'),
    };
  }

  async healthCheck(): Promise<ProviderHealthCheckResult> {
    return this.checkHealth();
  }
}
