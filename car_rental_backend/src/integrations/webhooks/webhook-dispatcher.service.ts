import { Injectable, Logger, Optional, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../admin/audit-log.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { IntegrationCategory } from '../registry/provider.types';
import {
  WebhookIngestParams,
  WebhookProcessResult,
  NormalizedGenericWebhookEvent,
} from './webhook.types';
import { WebhookVerificationError } from '../errors/integration-error';
import * as crypto from 'crypto';

@Injectable()
export class WebhookDispatcherService {
  private readonly logger = new Logger(WebhookDispatcherService.name);
  private static readonly REPLAY_TOLERANCE_SECONDS = 300; // 5 minutes

  constructor(
    private readonly prisma: PrismaService,
    private readonly providerRegistry: ProviderRegistryService,
    @Optional() private readonly auditLogService?: AuditLogService,
  ) {}

  /**
   * Ingests, verifies, deduplicates, and processes an incoming webhook.
   */
  async ingestWebhook(
    params: WebhookIngestParams,
    handler?: (normalizedEvent: NormalizedGenericWebhookEvent) => Promise<any>,
  ): Promise<WebhookProcessResult> {
    const { gateway, rawBody, signature, headers, secret, timestamp } = params;

    // 1. Replay Protection: Check timestamp freshness if available in headers or params
    this.verifyReplayProtection(headers, timestamp);

    // 2. Parse payload safely
    let parsedPayload: any;
    try {
      parsedPayload = JSON.parse(rawBody);
    } catch {
      throw new BadRequestException('Malformed webhook JSON payload');
    }

    // 3. Extract unique deterministic event ID
    const eventId = this.extractEventId(parsedPayload, headers, rawBody);
    const eventType =
      parsedPayload.event ||
      parsedPayload.type ||
      (headers && headers['x-event-type']) ||
      'unknown.event';

    // 4. Cryptographic Signature Verification via Provider or Verifier
    this.verifySignature(gateway, rawBody, signature, secret, headers);

    // 5. Persistent Deduplication & Idempotency Check in WebhookEvent table
    if (this.prisma.webhookEvent) {
      try {
        const existing = await this.prisma.webhookEvent.findUnique({
          where: { eventId: String(eventId) },
        });

        if (existing) {
          this.logger.log(
            `[WEBHOOK_DEDUPLICATION] Event [${eventId}] already recorded with status [${existing.status}]. Skipping.`,
          );
          return {
            received: true,
            duplicate: true,
            alreadyProcessed: true,
            eventId: String(eventId),
            eventType: String(eventType),
            status: 'DUPLICATE',
          };
        }

        // Insert initial RECEIVED record
        await this.prisma.webhookEvent.create({
          data: {
            gateway: gateway.toUpperCase(),
            eventId: String(eventId),
            eventType: String(eventType),
            payload: parsedPayload,
            signature: signature ? signature.substring(0, 255) : null,
            status: 'RECEIVED',
          },
        });
      } catch (err: any) {
        if (
          err?.code === 'P2002' ||
          err?.message?.includes('Unique constraint') ||
          err?.message?.includes('duplicate key')
        ) {
          this.logger.log(
            `[WEBHOOK_DEDUPLICATION] Concurrent insert hit unique constraint for event [${eventId}]. Skipping.`,
          );
          return {
            received: true,
            duplicate: true,
            alreadyProcessed: true,
            eventId: String(eventId),
            eventType: String(eventType),
            status: 'DUPLICATE',
          };
        }
        this.logger.warn(`Failed writing to WebhookEvent table: ${err?.message}`);
      }
    }

    // 6. Event Normalization
    const normalizedEvent: NormalizedGenericWebhookEvent = {
      eventId: String(eventId),
      gateway: gateway.toUpperCase(),
      eventType: String(eventType),
      aggregateId: parsedPayload.id || parsedPayload.order_id || parsedPayload.payment_id,
      timestamp: new Date(),
      payload: parsedPayload,
    };

    // 7. Execution & Status Tracking
    try {
      let handlerResult: any = null;
      if (handler) {
        handlerResult = await handler(normalizedEvent);
      }

      // Mark status PROCESSED in DB
      if (this.prisma.webhookEvent) {
        await this.prisma.webhookEvent.update({
          where: { eventId: String(eventId) },
          data: {
            status: 'PROCESSED',
            processedAt: new Date(),
          },
        }).catch(() => null);
      }

      // Audit Log
      await this.recordAuditLog(gateway, eventId, eventType, 'PROCESSED');

      return {
        received: true,
        duplicate: false,
        eventId: String(eventId),
        eventType: String(eventType),
        status: 'PROCESSED',
        data: handlerResult,
      };
    } catch (err: any) {
      this.logger.error(`[WEBHOOK_PROCESSING_FAILED] Event [${eventId}]: ${err?.message}`, err?.stack);

      // Mark status FAILED in DB
      if (this.prisma.webhookEvent) {
        await this.prisma.webhookEvent.update({
          where: { eventId: String(eventId) },
          data: {
            status: 'FAILED',
            failureReason: err?.message?.substring(0, 500),
          },
        }).catch(() => null);
      }

      // Audit Log
      await this.recordAuditLog(gateway, eventId, eventType, 'FAILED', err?.message);

      return {
        received: true,
        duplicate: false,
        eventId: String(eventId),
        eventType: String(eventType),
        status: 'FAILED',
        error: err?.message,
      };
    }
  }

  /**
   * Replays a previously received or failed webhook event.
   */
  async replayWebhookEvent(
    eventId: string,
    handler: (event: NormalizedGenericWebhookEvent) => Promise<any>,
  ): Promise<WebhookProcessResult> {
    const record = await this.prisma.webhookEvent.findUnique({
      where: { eventId },
    });

    if (!record) {
      throw new BadRequestException(`Webhook event with ID [${eventId}] not found.`);
    }

    this.logger.log(`[WEBHOOK_REPLAY] Replaying event [${eventId}] (${record.gateway}/${record.eventType})`);

    const normalizedEvent: NormalizedGenericWebhookEvent = {
      eventId: record.eventId,
      gateway: record.gateway,
      eventType: record.eventType,
      timestamp: new Date(),
      payload: record.payload,
    };

    try {
      const result = await handler(normalizedEvent);

      await this.prisma.webhookEvent.update({
        where: { eventId },
        data: {
          status: 'PROCESSED',
          processedAt: new Date(),
          failureReason: null,
        },
      });

      await this.recordAuditLog(record.gateway, eventId, record.eventType, 'REPLAY_SUCCESS');

      return {
        received: true,
        eventId,
        eventType: record.eventType,
        status: 'PROCESSED',
        data: result,
      };
    } catch (err: any) {
      await this.prisma.webhookEvent.update({
        where: { eventId },
        data: {
          status: 'FAILED',
          failureReason: `Replay failed: ${err?.message}`.substring(0, 500),
        },
      });

      return {
        received: true,
        eventId,
        eventType: record.eventType,
        status: 'FAILED',
        error: err?.message,
      };
    }
  }

  /**
   * Enforces replay protection by rejecting requests whose timestamp is outside the tolerance window.
   */
  private verifyReplayProtection(headers?: Record<string, any>, explicitTimestamp?: number): void {
    let headerTime: number | null = explicitTimestamp ?? null;

    if (!headerTime && headers) {
      const tsHeader =
        headers['x-event-time'] ||
        headers['x-razorpay-event-time'] ||
        headers['stripe-signature-timestamp'];
      if (tsHeader) {
        headerTime = parseInt(tsHeader, 10);
        // If in seconds, convert to ms
        if (headerTime < 10000000000) {
          headerTime *= 1000;
        }
      }
    }

    if (headerTime) {
      const now = Date.now();
      const diffSeconds = Math.abs(now - headerTime) / 1000;
      if (diffSeconds > WebhookDispatcherService.REPLAY_TOLERANCE_SECONDS) {
        this.logger.warn(`[WEBHOOK_REPLAY_DETECTED] Timestamp diff ${diffSeconds}s exceeds allowed tolerance ${WebhookDispatcherService.REPLAY_TOLERANCE_SECONDS}s`);
        throw new WebhookVerificationError(
          'webhook',
          IntegrationCategory.PAYMENT,
          `Webhook timestamp is outside the allowed replay tolerance window (${Math.round(diffSeconds)}s old).`,
        );
      }
    }
  }

  /**
   * Deterministically resolves or extracts an eventId.
   */
  private extractEventId(payload: any, headers?: Record<string, any>, rawBody?: string): string {
    const fromHeader =
      headers &&
      (headers['x-razorpay-event-id'] ||
        headers['x-event-id'] ||
        headers['webhook-id'] ||
        headers['stripe-event-id']);

    if (fromHeader) return String(fromHeader);
    if (payload?.event_id) return String(payload.event_id);
    if (payload?.id && typeof payload.id === 'string' && !payload.id.startsWith('pay_')) {
      return String(payload.id);
    }

    // Fallback: SHA-256 hash of rawBody
    return crypto.createHash('sha256').update(rawBody || JSON.stringify(payload)).digest('hex');
  }

  /**
   * Verifies the signature of the incoming webhook.
   */
  private verifySignature(
    gateway: string,
    rawBody: string,
    signature: string,
    secret?: string,
    headers?: Record<string, any>,
  ): void {
    // Check mock mode bypass
    if (signature === 'mock_signature' && process.env.NODE_ENV !== 'production') {
      return;
    }

    if (!signature) {
      throw new WebhookVerificationError(
        gateway,
        IntegrationCategory.PAYMENT,
        'Missing webhook signature header',
      );
    }

    // If HMAC secret is provided, verify using standard HMAC SHA256
    if (secret) {
      const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(rawBody)
        .digest('hex');

      const sigBuf = Buffer.from(signature, 'utf8');
      const expectedBuf = Buffer.from(expectedSignature, 'utf8');

      const isValid =
        sigBuf.length === expectedBuf.length &&
        crypto.timingSafeEqual(sigBuf, expectedBuf);

      if (!isValid) {
        throw new WebhookVerificationError(
          gateway,
          IntegrationCategory.PAYMENT,
          'Cryptographic signature does not match expected payload digest',
        );
      }
    }
  }

  private async recordAuditLog(
    gateway: string,
    eventId: string,
    eventType: string,
    action: string,
    errorMessage?: string,
  ): Promise<void> {
    if (!this.auditLogService) return;
    try {
      await this.auditLogService.log(
        'system',
        `WEBHOOK_${action}`,
        'INTEGRATION_WEBHOOK',
        eventId,
        {
          gateway,
          eventType,
          errorMessage,
          timestamp: new Date().toISOString(),
        },
      );
    } catch (_) {}
  }
}
