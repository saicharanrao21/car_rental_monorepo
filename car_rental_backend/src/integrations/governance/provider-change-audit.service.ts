import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IntegrationCategory } from '../registry/provider.types';

export enum ProviderChangeType {
  CREDENTIAL_UPDATE = 'CREDENTIAL_UPDATE',
  ACTIVATION_STATE_CHANGE = 'ACTIVATION_STATE_CHANGE',
  PRIORITY_UPDATE = 'PRIORITY_UPDATE',
  ROUTING_POLICY_CHANGE = 'ROUTING_POLICY_CHANGE',
  FALLBACK_CHAIN_CHANGE = 'FALLBACK_CHAIN_CHANGE',
  ENVIRONMENT_CHANGE = 'ENVIRONMENT_CHANGE',
  WEBHOOK_CONFIG_CHANGE = 'WEBHOOK_CONFIG_CHANGE',
  API_VERSION_CHANGE = 'API_VERSION_CHANGE',
  ONBOARDING_INITIALIZED = 'ONBOARDING_INITIALIZED',
  ONBOARDING_COMPLETED = 'ONBOARDING_COMPLETED',
  CIRCUIT_RESET = 'CIRCUIT_RESET',
}

export interface RecordChangeEventDto {
  providerId: string;
  category: IntegrationCategory;
  changeType: ProviderChangeType;
  environment?: string;
  actorId: string;
  actorRole: string;
  reason?: string;
  beforeSnapshot?: Record<string, any>;
  afterSnapshot?: Record<string, any>;
}

export interface ProviderChangeEventRecord {
  id: string;
  eventId: string;
  providerId: string;
  category: IntegrationCategory;
  changeType: ProviderChangeType;
  environment: string;
  actorId: string;
  actorRole: string;
  reason?: string;
  beforeSnapshot?: Record<string, any>;
  afterSnapshot?: Record<string, any>;
  createdAt: Date;
}

@Injectable()
export class ProviderChangeAuditService {
  private readonly logger = new Logger(ProviderChangeAuditService.name);
  private readonly memoryLog: ProviderChangeEventRecord[] = [];

  // Keys that must ALWAYS be sanitized/redacted in audit logs
  private readonly sensitivePatterns = [
    'secret',
    'password',
    'token',
    'apikey',
    'api_key',
    'privatekey',
    'private_key',
    'keysecret',
    'key_secret',
    'auth',
    'credential',
    'signature',
    'webhooksecret',
    'webhook_secret',
  ];

  constructor(@Optional() private readonly prisma?: PrismaService) {}

  /**
   * Records a provider configuration or status change with strict secret sanitization.
   */
  public async recordChange(dto: RecordChangeEventDto): Promise<ProviderChangeEventRecord> {
    const eventId = `evt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const sanitizedBefore = dto.beforeSnapshot ? this.sanitizePayload(dto.beforeSnapshot) : undefined;
    const sanitizedAfter = dto.afterSnapshot ? this.sanitizePayload(dto.afterSnapshot) : undefined;

    const record: ProviderChangeEventRecord = {
      id: eventId,
      eventId,
      providerId: dto.providerId,
      category: dto.category,
      changeType: dto.changeType,
      environment: dto.environment || 'SANDBOX',
      actorId: dto.actorId,
      actorRole: dto.actorRole,
      reason: dto.reason,
      beforeSnapshot: sanitizedBefore,
      afterSnapshot: sanitizedAfter,
      createdAt: new Date(),
    };

    this.memoryLog.unshift(record); // Prepend for latest-first

    this.logger.log(
      `[PROVIDER_CHANGE_AUDIT] Change [${record.changeType}] recorded on provider [${record.providerId}] by actor [${record.actorId}]. Reason: ${record.reason || 'N/A'}`,
    );

    await this.persistChangeEvent(record);
    return record;
  }

  /**
   * Get recent change events with optional filters.
   */
  public queryChangeHistory(filter?: {
    providerId?: string;
    category?: IntegrationCategory;
    changeType?: ProviderChangeType;
    actorId?: string;
    limit?: number;
  }): ProviderChangeEventRecord[] {
    let list = [...this.memoryLog];

    if (!filter) return list.slice(0, 50);

    if (filter.providerId) {
      const pid = filter.providerId.toLowerCase();
      list = list.filter((e) => e.providerId.toLowerCase() === pid);
    }

    if (filter.category) {
      list = list.filter((e) => e.category === filter.category);
    }

    if (filter.changeType) {
      list = list.filter((e) => e.changeType === filter.changeType);
    }

    if (filter.actorId) {
      list = list.filter((e) => e.actorId === filter.actorId);
    }

    const limit = filter.limit || 50;
    return list.slice(0, limit);
  }

  /**
   * Recursively sanitizes an object, replacing sensitive keys or patterns with `***REDACTED***`.
   */
  public sanitizePayload(payload: any): any {
    if (!payload || typeof payload !== 'object') {
      return payload;
    }

    if (Array.isArray(payload)) {
      return payload.map((item) => this.sanitizePayload(item));
    }

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(payload)) {
      const lowerKey = key.toLowerCase();
      const isSensitive = this.sensitivePatterns.some((pattern) => lowerKey.includes(pattern));

      if (isSensitive) {
        sanitized[key] = '***REDACTED***';
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitizePayload(value);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  private async persistChangeEvent(record: ProviderChangeEventRecord): Promise<void> {
    if (!this.prisma) return;
    try {
      await (this.prisma as any).providerChangeEvent.create({
        data: {
          eventId: record.eventId,
          providerId: record.providerId,
          category: record.category,
          changeType: record.changeType,
          environment: record.environment,
          actorId: record.actorId,
          actorRole: record.actorRole,
          reason: record.reason,
          beforeSnapshot: record.beforeSnapshot,
          afterSnapshot: record.afterSnapshot,
          createdAt: record.createdAt,
        },
      });
    } catch (err: any) {
      this.logger.debug(`Could not persist change event to DB (safely ignored): ${err.message}`);
    }
  }
}
