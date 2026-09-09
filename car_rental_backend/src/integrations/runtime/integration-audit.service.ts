import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  IntegrationExecutionRequest,
  IntegrationExecutionResult,
  CircuitState,
} from './runtime.types';

@Injectable()
export class IntegrationAuditService {
  private readonly logger = new Logger('IntegrationAuditTelemetry');
  private readonly inMemoryExecutions: any[] = [];
  private readonly inMemoryIncidents: any[] = [];
  private readonly MAX_IN_MEMORY = 500;

  constructor(@Optional() private readonly prisma?: PrismaService) {}

  /**
   * Sanitizes payloads to prevent secrets, tokens, cards, or passwords from appearing in logs or database.
   */
  public sanitize(obj: any): any {
    if (!obj || typeof obj !== 'object') {
      return obj;
    }
    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitize(item));
    }

    const sanitized: Record<string, any> = {};
    const sensitiveRegex = /key|secret|token|password|auth|cvv|card_number|pan|credential|private/i;

    for (const [k, v] of Object.entries(obj)) {
      if (sensitiveRegex.test(k)) {
        sanitized[k] = '***REDACTED***';
      } else if (v && typeof v === 'object') {
        sanitized[k] = this.sanitize(v);
      } else {
        sanitized[k] = v;
      }
    }
    return sanitized;
  }

  /**
   * Records an integration execution and its attempts to structured telemetry and persistent store.
   */
  public async recordExecution(
    request: IntegrationExecutionRequest,
    result: IntegrationExecutionResult,
  ): Promise<void> {
    const sanitizedRequest = this.sanitize(request.payload);
    const sanitizedResponse = this.sanitize(result.data || result.error);

    // 1. Structured Telemetry Log
    const telemetry = {
      event: 'INTEGRATION_EXECUTION',
      correlationId: result.correlationId,
      category: result.category,
      capability: result.capability,
      providerId: result.providerId,
      finalProviderId: result.success ? result.providerId : undefined,
      environment: result.environment,
      tenantId: request.tenantId,
      vendorId: request.vendorId,
      branchId: request.branchId,
      status: result.success ? 'SUCCESS' : 'FAILED',
      latencyMs: result.latencyMs,
      fallbackOccurred: result.fallbackOccurred,
      attemptCount: result.attempts.length,
      errorClassification: result.error?.classification,
      errorMessage: result.error?.message,
      idempotencyKeyRef: request.idempotencyKey ? `${request.idempotencyKey.substring(0, 8)}...` : undefined,
      timestamp: new Date().toISOString(),
    };

    if (result.success) {
      this.logger.log(JSON.stringify(telemetry));
    } else {
      this.logger.warn(JSON.stringify(telemetry));
    }

    const executionRecord = {
      id: `exec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      correlationId: result.correlationId,
      category: result.category,
      capability: result.capability,
      status: result.success ? 'SUCCESS' : 'FAILED',
      providerId: result.attempts[0]?.providerId || result.providerId,
      finalProviderId: result.providerId,
      fallbackOccurred: result.fallbackOccurred,
      environment: result.environment,
      tenantId: request.tenantId,
      vendorId: request.vendorId,
      branchId: request.branchId,
      region: request.region,
      currency: request.currency,
      idempotencyKey: request.idempotencyKey,
      requestPayload: sanitizedRequest,
      responsePayload: sanitizedResponse,
      errorClassification: result.error?.classification,
      errorMessage: result.error?.message,
      latencyMs: result.latencyMs,
      metadata: request.metadata,
      createdAt: new Date(),
      attempts: result.attempts.map((a) => ({
        id: `att_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        attemptNumber: a.attemptNumber,
        providerId: a.providerId,
        status: a.status,
        errorClassification: a.errorClassification,
        errorMessage: a.errorMessage,
        latencyMs: a.latencyMs,
        createdAt: a.timestamp,
      })),
    };

    // Keep in-memory
    this.inMemoryExecutions.unshift(executionRecord);
    if (this.inMemoryExecutions.length > this.MAX_IN_MEMORY) {
      this.inMemoryExecutions.pop();
    }

    // Persist to Prisma if available
    if (this.prisma && (this.prisma as any).integrationExecution) {
      try {
        await (this.prisma as any).integrationExecution.create({
          data: {
            correlationId: executionRecord.correlationId,
            category: executionRecord.category,
            capability: executionRecord.capability,
            status: executionRecord.status,
            providerId: executionRecord.providerId,
            finalProviderId: executionRecord.finalProviderId,
            fallbackOccurred: executionRecord.fallbackOccurred,
            environment: executionRecord.environment,
            tenantId: executionRecord.tenantId,
            vendorId: executionRecord.vendorId,
            branchId: executionRecord.branchId,
            region: executionRecord.region,
            currency: executionRecord.currency,
            idempotencyKey: executionRecord.idempotencyKey,
            requestPayload: sanitizedRequest,
            responsePayload: sanitizedResponse,
            errorClassification: executionRecord.errorClassification,
            errorMessage: executionRecord.errorMessage,
            latencyMs: executionRecord.latencyMs,
            metadata: executionRecord.metadata,
            attempts: {
              create: executionRecord.attempts.map((a) => ({
                attemptNumber: a.attemptNumber,
                providerId: a.providerId,
                status: a.status,
                errorClassification: a.errorClassification,
                errorMessage: a.errorMessage,
                latencyMs: a.latencyMs,
              })),
            },
          },
        });
      } catch (err: any) {
        this.logger.debug(`Prisma persistence skipped or error: ${err.message}`);
      }
    }
  }

  /**
   * Records or updates a provider incident.
   */
  public async recordIncident(params: {
    providerId: string;
    category: string;
    title: string;
    severity?: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
    circuitState?: CircuitState;
    reason?: string;
  }): Promise<any> {
    const existing = this.inMemoryIncidents.find(
      (i) =>
        i.providerId === params.providerId &&
        i.status !== 'RESOLVED' &&
        i.category === params.category,
    );

    if (existing) {
      existing.circuitState = params.circuitState || existing.circuitState;
      existing.reason = params.reason || existing.reason;
      existing.updatedAt = new Date();
      return existing;
    }

    const incident = {
      id: `inc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      providerId: params.providerId,
      category: params.category,
      title: params.title,
      status: 'INVESTIGATING',
      severity: params.severity || 'MEDIUM',
      circuitState: params.circuitState || 'OPEN',
      startedAt: new Date(),
      reason: params.reason,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.inMemoryIncidents.unshift(incident);

    if (this.prisma && (this.prisma as any).providerIncident) {
      try {
        await (this.prisma as any).providerIncident.create({
          data: incident,
        });
      } catch (err: any) {
        this.logger.debug(`Could not persist incident to DB: ${err.message}`);
      }
    }

    return incident;
  }

  /**
   * Resolves an open incident.
   */
  public async resolveIncident(providerId: string, reason?: string): Promise<void> {
    for (const inc of this.inMemoryIncidents) {
      if (inc.providerId === providerId && inc.status !== 'RESOLVED') {
        inc.status = 'RESOLVED';
        inc.resolvedAt = new Date();
        inc.updatedAt = new Date();
      }
    }

    if (this.prisma && (this.prisma as any).providerIncident) {
      try {
        await (this.prisma as any).providerIncident.updateMany({
          where: { providerId, status: { not: 'RESOLVED' } },
          data: { status: 'RESOLVED', resolvedAt: new Date(), reason: reason || 'Circuit recovered' },
        });
      } catch (err: any) {
        this.logger.debug(`Could not update incident in DB: ${err.message}`);
      }
    }
  }

  public getIncidents(filter?: { providerId?: string; status?: string }): any[] {
    let list = [...this.inMemoryIncidents];
    if (filter?.providerId) {
      list = list.filter((i) => i.providerId.toLowerCase() === filter.providerId!.toLowerCase());
    }
    if (filter?.status) {
      list = list.filter((i) => i.status === filter.status);
    }
    return list;
  }

  public getExecutions(filter?: {
    category?: string;
    providerId?: string;
    status?: string;
    limit?: number;
    offset?: number;
  }): any[] {
    let list = [...this.inMemoryExecutions];
    if (filter?.category) {
      list = list.filter((e) => e.category === filter.category);
    }
    if (filter?.providerId) {
      list = list.filter(
        (e) =>
          e.providerId.toLowerCase() === filter.providerId!.toLowerCase() ||
          e.finalProviderId?.toLowerCase() === filter.providerId!.toLowerCase(),
      );
    }
    if (filter?.status) {
      list = list.filter((e) => e.status === filter.status);
    }
    const offset = filter?.offset || 0;
    const limit = filter?.limit || 50;
    return list.slice(offset, offset + limit);
  }

  public getExecutionByCorrelationId(correlationId: string): any {
    return this.inMemoryExecutions.find((e) => e.correlationId === correlationId);
  }
}
