import { Test, TestingModule } from '@nestjs/testing';
import { WebhookDispatcherService } from '../webhooks/webhook-dispatcher.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../admin/audit-log.service';
import {
  IntegrationCategory,
  ProviderHealthStatus,
} from '../registry/provider.types';
import { WebhookVerificationError } from '../errors/integration-error';
import * as crypto from 'crypto';

describe('Phase I — Generic Webhook Foundation & Health Monitoring', () => {
  let dispatcher: WebhookDispatcherService;
  let healthService: ProviderHealthService;

  const mockWebhookEvents: Map<string, any> = new Map();

  const mockPrismaService = {
    webhookEvent: {
      findUnique: jest.fn().mockImplementation(({ where }: { where: { eventId: string } }) => {
        return Promise.resolve(mockWebhookEvents.get(where.eventId) || null);
      }),
      create: jest.fn().mockImplementation(({ data }: { data: any }) => {
        if (mockWebhookEvents.has(data.eventId)) {
          const err: any = new Error('Unique constraint failed on the fields: (`eventId`)');
          err.code = 'P2002';
          return Promise.reject(err);
        }
        mockWebhookEvents.set(data.eventId, { ...data, createdAt: new Date() });
        return Promise.resolve(mockWebhookEvents.get(data.eventId));
      }),
      update: jest.fn().mockImplementation(({ where, data }: { where: { eventId: string }; data: any }) => {
        const existing = mockWebhookEvents.get(where.eventId);
        if (!existing) return Promise.reject(new Error('Record not found'));
        const updated = { ...existing, ...data };
        mockWebhookEvents.set(where.eventId, updated);
        return Promise.resolve(updated);
      }),
    },
  };

  beforeEach(async () => {
    mockWebhookEvents.clear();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WebhookDispatcherService,
        ProviderHealthService,
        {
          provide: ProviderRegistryService,
          useValue: {
            getProvider: jest.fn(),
          },
        },
        { provide: PrismaService, useValue: mockPrismaService },
        {
          provide: AuditLogService,
          useValue: { log: jest.fn().mockResolvedValue({}) },
        },
      ],
    }).compile();

    dispatcher = module.get<WebhookDispatcherService>(WebhookDispatcherService);
    healthService = module.get<ProviderHealthService>(ProviderHealthService);
  });

  describe('Webhook Ingestion & Signature Verification', () => {
    it('should successfully ingest and process a webhook with valid HMAC signature', async () => {
      const secret = 'webhook_secret_key_123';
      const payload = {
        id: 'evt_rzp_order_paid_123',
        event: 'order.paid',
        payload: { payment: { entity: { id: 'pay_999', amount: 50000 } } },
      };
      const rawBody = JSON.stringify(payload);
      const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

      const handler = jest.fn().mockResolvedValue({ processed: true });

      const result = await dispatcher.ingestWebhook(
        {
          gateway: 'RAZORPAY',
          rawBody,
          signature,
          secret,
        },
        handler,
      );

      expect(result.received).toBe(true);
      expect(result.status).toBe('PROCESSED');
      expect(result.eventId).toBe('evt_rzp_order_paid_123');
      expect(handler).toHaveBeenCalledTimes(1);

      // Verify stored in DB
      const stored = mockWebhookEvents.get('evt_rzp_order_paid_123');
      expect(stored).toBeDefined();
      expect(stored.status).toBe('PROCESSED');
    });

    it('should reject webhook with invalid signature throwing WebhookVerificationError', async () => {
      const secret = 'webhook_secret_key_123';
      const rawBody = JSON.stringify({ id: 'evt_fake', event: 'order.paid' });
      const badSignature = 'invalid_signature_hex_value';

      await expect(
        dispatcher.ingestWebhook({
          gateway: 'RAZORPAY',
          rawBody,
          signature: badSignature,
          secret,
        }),
      ).rejects.toThrow(WebhookVerificationError);
    });
  });

  describe('Webhook Idempotency & Deduplication', () => {
    it('should deduplicate already processed webhook events without executing handler twice', async () => {
      const secret = 'webhook_secret_key_123';
      const payload = { id: 'evt_duplicate_test', event: 'payment.captured' };
      const rawBody = JSON.stringify(payload);
      const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

      const handler = jest.fn().mockResolvedValue({ success: true });

      // 1. First Ingestion
      const firstResult = await dispatcher.ingestWebhook(
        { gateway: 'RAZORPAY', rawBody, signature, secret },
        handler,
      );
      expect(firstResult.status).toBe('PROCESSED');
      expect(handler).toHaveBeenCalledTimes(1);

      // 2. Second Ingestion of identical event
      const secondResult = await dispatcher.ingestWebhook(
        { gateway: 'RAZORPAY', rawBody, signature, secret },
        handler,
      );
      expect(secondResult.duplicate).toBe(true);
      expect(secondResult.alreadyProcessed).toBe(true);
      expect(secondResult.status).toBe('DUPLICATE');

      // Handler must NOT have been called again!
      expect(handler).toHaveBeenCalledTimes(1);
    });
  });

  describe('Webhook Replay Protection', () => {
    it('should reject webhook events that exceed replay protection tolerance (> 300 seconds old)', async () => {
      const secret = 'webhook_secret_key_123';
      const rawBody = JSON.stringify({ id: 'evt_stale', event: 'payment.captured' });
      const signature = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

      const staleTimestampSeconds = Math.floor(Date.now() / 1000) - 600; // 10 minutes old

      await expect(
        dispatcher.ingestWebhook({
          gateway: 'RAZORPAY',
          rawBody,
          signature,
          secret,
          timestamp: staleTimestampSeconds,
        }),
      ).rejects.toThrow(WebhookVerificationError);
    });
  });

  describe('ProviderHealthService', () => {
    it('should record healthy and degraded health states accurately', () => {
      // 1. Healthy check
      healthService.recordHealth(IntegrationCategory.PAYMENT, 'razorpay', {
        status: ProviderHealthStatus.HEALTHY,
        latencyMs: 45,
        lastChecked: new Date(),
      });

      const h1 = healthService.getHealth(IntegrationCategory.PAYMENT, 'razorpay');
      expect(h1.status).toBe(ProviderHealthStatus.HEALTHY);
      expect(h1.latencyMs).toBe(45);
      expect(h1.lastSuccessfulCheck).toBeInstanceOf(Date);
      expect(h1.lastFailedCheck).toBeNull();

      // 2. Failed check
      healthService.recordHealth(IntegrationCategory.PAYMENT, 'razorpay', {
        status: ProviderHealthStatus.CREDENTIAL_FAILURE,
        latencyMs: 120,
        message: 'Invalid API secret key',
        lastChecked: new Date(),
      });

      const h2 = healthService.getHealth(IntegrationCategory.PAYMENT, 'razorpay');
      expect(h2.status).toBe(ProviderHealthStatus.CREDENTIAL_FAILURE);
      expect(h2.lastFailedCheck).toBeInstanceOf(Date);
      expect(h2.lastErrorMessage).toBe('Invalid API secret key');
    });
  });
});
