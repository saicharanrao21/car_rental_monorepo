import { Injectable, Logger } from '@nestjs/common';
import { CorrelationTimelineEntry, DomainEvent } from './operations-domain.types';

@Injectable()
export class OperationsAuditTracerService {
  private readonly logger = new Logger(OperationsAuditTracerService.name);

  // In-memory correlation trace store: correlationId -> CorrelationTimelineEntry[]
  private readonly traces = new Map<string, CorrelationTimelineEntry[]>();
  private readonly allEntries: CorrelationTimelineEntry[] = [];
  private readonly MAX_ENTRIES = 5000;

  /**
   * Record a cross-domain operational activity linked to a correlation ID.
   */
  public recordActivity(params: {
    correlationId: string;
    sourceDomain: 'CUSTOMER' | 'BOOKINGS' | 'PAYMENTS' | 'FLEET' | 'INTEGRATIONS' | 'WORKFLOW' | 'NOTIFICATIONS' | 'APPROVAL';
    activity: string;
    status: 'SUCCESS' | 'WARNING' | 'FAILED' | 'INFO';
    details?: Record<string, any>;
  }): CorrelationTimelineEntry {
    const traceId = `trc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const sanitizedDetails = this.sanitizeDetails(params.details);

    const entry: CorrelationTimelineEntry = {
      traceId,
      correlationId: params.correlationId,
      timestamp: new Date().toISOString(),
      sourceDomain: params.sourceDomain,
      activity: params.activity,
      status: params.status,
      details: sanitizedDetails,
    };

    if (!this.traces.has(params.correlationId)) {
      this.traces.set(params.correlationId, []);
    }
    this.traces.get(params.correlationId)!.push(entry);

    if (this.allEntries.length >= this.MAX_ENTRIES) {
      const removed = this.allEntries.shift();
      if (removed) {
        const corrList = this.traces.get(removed.correlationId);
        if (corrList) {
          const idx = corrList.findIndex((t) => t.traceId === removed.traceId);
          if (idx !== -1) corrList.splice(idx, 1);
        }
      }
    }
    this.allEntries.push(entry);

    this.logger.debug(
      `[AUDIT_TIMELINE] ${params.sourceDomain} -> ${params.activity} (${params.status}) [Corr: ${params.correlationId}]`,
    );

    return entry;
  }

  /**
   * Automatically records timeline events from domain events.
   */
  public recordFromDomainEvent(event: DomainEvent): CorrelationTimelineEntry {
    const domainMapping: Record<string, any> = {
      BOOKING: 'BOOKINGS',
      PAYMENT: 'PAYMENTS',
      VEHICLE: 'FLEET',
      VENDOR: 'CUSTOMER',
      CUSTOMER: 'CUSTOMER',
      COMPLIANCE: 'APPROVAL',
      SYSTEM: 'WORKFLOW',
    };

    const sourceDomain = domainMapping[event.aggregateType] || 'WORKFLOW';

    return this.recordActivity({
      correlationId: event.correlationId,
      sourceDomain,
      activity: `DomainEvent: ${event.eventType} on ${event.aggregateType}#${event.aggregateId}`,
      status: event.eventType.toString().includes('FAILED') ? 'FAILED' : 'SUCCESS',
      details: {
        eventId: event.eventId,
        eventType: event.eventType,
        aggregateType: event.aggregateType,
        aggregateId: event.aggregateId,
        actor: event.actor,
        tenantContext: event.tenantContext,
      },
    });
  }

  /**
   * Get the full unified chronological timeline for a correlation ID.
   */
  public getTimelineByCorrelationId(correlationId: string): CorrelationTimelineEntry[] {
    const entries = this.traces.get(correlationId) || [];
    return [...entries].sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
  }

  /**
   * Search recent activities with filters.
   */
  public queryTimeline(filter?: {
    domain?: string;
    status?: string;
    limit?: number;
  }): CorrelationTimelineEntry[] {
    let list = [...this.allEntries];
    if (filter?.domain) {
      list = list.filter((e) => e.sourceDomain === filter.domain);
    }
    if (filter?.status) {
      list = list.filter((e) => e.status === filter.status);
    }
    const limit = filter?.limit || 100;
    return list.slice(-limit).reverse();
  }

  /**
   * Mask secrets, tokens, card numbers, passwords.
   */
  private sanitizeDetails(details?: Record<string, any>): Record<string, any> | undefined {
    if (!details) return undefined;
    const sensitiveKeys = ['password', 'token', 'secret', 'apikey', 'key', 'authorization', 'cardnumber', 'cvv', 'access_token'];
    
    const sanitize = (obj: any): any => {
      if (obj === null || obj === undefined) return obj;
      if (typeof obj !== 'object') return obj;
      if (Array.isArray(obj)) return obj.map(sanitize);

      const copy: Record<string, any> = {};
      for (const [k, v] of Object.entries(obj)) {
        if (sensitiveKeys.some((s) => k.toLowerCase().includes(s))) {
          copy[k] = '***REDACTED***';
        } else if (typeof v === 'object') {
          copy[k] = sanitize(v);
        } else {
          copy[k] = v;
        }
      }
      return copy;
    };

    return sanitize(details);
  }
}
