import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { DomainEvent, DomainEventType } from './operations-domain.types';

export type DomainEventHandler<T = any> = (event: DomainEvent<T>) => Promise<void> | void;

@Injectable()
export class DomainEventBusService implements OnModuleDestroy {
  private readonly logger = new Logger(DomainEventBusService.name);

  // In-memory subscription registry: eventType -> array of handlers
  private readonly subscriptions = new Map<string, Array<{ handlerId: string; handler: DomainEventHandler }>>();
  // Wildcard handlers (receive all events)
  private readonly globalHandlers = new Array<{ handlerId: string; handler: DomainEventHandler }>();

  // Deduplication cache: eventId -> timestamp (expires after TTL)
  private readonly processedEventIds = new Map<string, number>();
  private readonly DEDUPLICATION_TTL_MS = 60 * 60 * 1000; // 1 hour

  // Event audit ring-buffer / history store (most recent 2000 events)
  private readonly eventStore: DomainEvent[] = [];
  private readonly MAX_STORED_EVENTS = 2000;

  private cleanupInterval: NodeJS.Timeout | null = null;

  constructor() {
    // Schedule periodic cleanup of deduplication cache
    this.cleanupInterval = setInterval(() => this.cleanupDeduplicationCache(), 15 * 60 * 1000);
    if (this.cleanupInterval.unref) {
      this.cleanupInterval.unref();
    }
  }

  onModuleDestroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  /**
   * Subscribe to a specific domain event type.
   */
  public subscribe<T = any>(
    eventType: DomainEventType | string,
    handlerId: string,
    handler: DomainEventHandler<T>,
  ): () => void {
    const key = eventType.toString();
    if (!this.subscriptions.has(key)) {
      this.subscriptions.set(key, []);
    }
    const handlers = this.subscriptions.get(key)!;
    handlers.push({ handlerId, handler });
    this.logger.debug(`Registered handler [${handlerId}] for event [${key}]`);

    return () => {
      const idx = handlers.findIndex((h) => h.handlerId === handlerId);
      if (idx !== -1) handlers.splice(idx, 1);
    };
  }

  /**
   * Subscribe to all domain events globally (e.g. for audit tracing or rule engine).
   */
  public subscribeGlobal(handlerId: string, handler: DomainEventHandler): () => void {
    this.globalHandlers.push({ handlerId, handler });
    this.logger.debug(`Registered global event listener [${handlerId}]`);

    return () => {
      const idx = this.globalHandlers.findIndex((h) => h.handlerId === handlerId);
      if (idx !== -1) this.globalHandlers.splice(idx, 1);
    };
  }

  /**
   * Publish a domain event with deduplication and correlation tracking.
   */
  public async publish<T = any>(event: DomainEvent<T>): Promise<{ published: boolean; duplicate: boolean }> {
    // 1. Deduplication check
    if (this.isDuplicate(event)) {
      this.logger.warn(
        `[DUPLICATE_EVENT_DROPPED] EventId ${event.eventId} (type: ${event.eventType}, agg: ${event.aggregateId}) was already processed.`,
      );
      return { published: false, duplicate: true };
    }

    // 2. Mark as processed
    this.processedEventIds.set(event.eventId, Date.now());

    // 3. Persist in ring buffer
    this.persistEvent(event);

    this.logger.log(
      `[DOMAIN_EVENT] Published ${event.eventType} (Agg: ${event.aggregateType}#${event.aggregateId}, Corr: ${event.correlationId})`,
    );

    // 4. Dispatch to topic subscribers
    const handlers = this.subscriptions.get(event.eventType.toString()) || [];
    const executionPromises: Promise<any>[] = [];

    for (const sub of handlers) {
      executionPromises.push(
        Promise.resolve()
          .then(() => sub.handler(event))
          .catch((err) => {
            this.logger.error(
              `Error in handler [${sub.handlerId}] for event [${event.eventType}]: ${err.message}`,
              err.stack,
            );
          }),
      );
    }

    // 5. Dispatch to global handlers
    for (const globalSub of this.globalHandlers) {
      executionPromises.push(
        Promise.resolve()
          .then(() => globalSub.handler(event))
          .catch((err) => {
            this.logger.error(
              `Error in global handler [${globalSub.handlerId}] for event [${event.eventType}]: ${err.message}`,
              err.stack,
            );
          }),
      );
    }

    await Promise.all(executionPromises);
    return { published: true, duplicate: false };
  }

  /**
   * Helper to construct and publish a standardized DomainEvent envelope.
   */
  public async emit<T = any>(params: {
    eventType: DomainEventType | string;
    aggregateType: 'BOOKING' | 'PAYMENT' | 'VEHICLE' | 'VENDOR' | 'CUSTOMER' | 'COMPLIANCE' | 'SYSTEM';
    aggregateId: string;
    payload: T;
    correlationId?: string;
    causationId?: string;
    tenantContext?: {
      tenantId?: string;
      vendorId?: string;
      branchId?: string;
    };
    actor?: {
      id: string;
      role: any;
      type?: string;
    };
  }): Promise<DomainEvent<T>> {
    const correlationId =
      params.correlationId || `cor_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const eventId = `evt_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    const envelope: DomainEvent<T> = {
      eventId,
      eventType: params.eventType,
      aggregateType: params.aggregateType,
      aggregateId: params.aggregateId,
      tenantContext: params.tenantContext,
      actor: params.actor || { id: 'SYSTEM', role: 'SYSTEM' },
      timestamp: new Date().toISOString(),
      correlationId,
      causationId: params.causationId,
      version: 1,
      payload: params.payload,
    };

    await this.publish(envelope);
    return envelope;
  }

  /**
   * Query event history with optional filters.
   */
  public queryEvents(filter?: {
    eventType?: string;
    aggregateType?: string;
    aggregateId?: string;
    correlationId?: string;
    vendorId?: string;
    limit?: number;
  }): DomainEvent[] {
    let result = [...this.eventStore];

    if (filter?.eventType) {
      result = result.filter((e) => e.eventType === filter.eventType);
    }
    if (filter?.aggregateType) {
      result = result.filter((e) => e.aggregateType === filter.aggregateType);
    }
    if (filter?.aggregateId) {
      result = result.filter((e) => e.aggregateId === filter.aggregateId);
    }
    if (filter?.correlationId) {
      result = result.filter((e) => e.correlationId === filter.correlationId);
    }
    if (filter?.vendorId) {
      result = result.filter((e) => e.tenantContext?.vendorId === filter.vendorId);
    }

    const limit = filter?.limit || 100;
    return result.slice(-limit).reverse();
  }

  public getEventCount(): number {
    return this.eventStore.length;
  }

  private isDuplicate(event: DomainEvent): boolean {
    if (this.processedEventIds.has(event.eventId)) {
      return true;
    }
    return false;
  }

  private persistEvent(event: DomainEvent): void {
    if (this.eventStore.length >= this.MAX_STORED_EVENTS) {
      this.eventStore.shift();
    }
    this.eventStore.push(event);
  }

  private cleanupDeduplicationCache(): void {
    const now = Date.now();
    for (const [id, timestamp] of this.processedEventIds.entries()) {
      if (now - timestamp > this.DEDUPLICATION_TTL_MS) {
        this.processedEventIds.delete(id);
      }
    }
  }
}
