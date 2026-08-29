import { Test, TestingModule } from '@nestjs/testing';
import { QueueFactoryService } from './queue-factory.service';
import { QueueProducerService } from './queue-producer.service';
import { ConfigService } from '@nestjs/config';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { QUEUE_NAMES, JOB_TYPES, DEFAULT_JOB_OPTIONS } from './queue.constants';

describe('Phase 27.1 — Background Worker & BullMQ Queue Foundation Tests', () => {
  let queueFactory: QueueFactoryService;
  let queueProducer: QueueProducerService;
  let mockRedis: any;

  beforeEach(async () => {
    mockRedis = {
      status: 'ready',
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QueueFactoryService,
        QueueProducerService,
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) => {
              if (key === 'REDIS_USE_MOCK') return 'true';
              if (key === 'REDIS_URL') return 'redis://localhost:6379';
              return null;
            },
          },
        },
        {
          provide: REDIS_CLIENT,
          useValue: mockRedis,
        },
      ],
    }).compile();

    queueFactory = module.get<QueueFactoryService>(QueueFactoryService);
    queueProducer = module.get<QueueProducerService>(QueueProducerService);
    queueFactory.onModuleInit();
  });

  afterEach(async () => {
    await queueFactory.onModuleDestroy();
  });

  describe('Queue Constants & Retry Policy', () => {
    it('verifies exponential backoff and retry policy configuration', () => {
      expect(DEFAULT_JOB_OPTIONS.attempts).toBe(3);
      expect(DEFAULT_JOB_OPTIONS.backoff.type).toBe('exponential');
      expect(DEFAULT_JOB_OPTIONS.backoff.delay).toBe(2000);
      expect(QUEUE_NAMES.NOTIFICATIONS).toBe('drivego-notifications-queue');
      expect(QUEUE_NAMES.WEBHOOKS).toBe('drivego-webhooks-queue');
      expect(QUEUE_NAMES.RECONCILIATION).toBe('drivego-reconciliation-queue');
      expect(QUEUE_NAMES.CLEANUP).toBe('drivego-cleanup-queue');
      expect(QUEUE_NAMES.ANALYTICS).toBe('drivego-analytics-queue');
    });
  });

  describe('QueueProducerService Job Dispatch', () => {
    it('dispatches SMS notification jobs with deterministic IDs', async () => {
      const res = await queueProducer.dispatchSmsNotification({
        phone: '9876543210',
        message: 'Your DriveGo OTP is 123456',
        otpCode: '123456',
      });

      expect(res.jobId).toContain('sms-9876543210');
      expect(res.status).toBe('PROCESSED_MOCK');
    });

    it('dispatches Email notification jobs', async () => {
      const res = await queueProducer.dispatchEmailNotification({
        to: 'customer@drivego.in',
        subject: 'Booking Confirmation',
        htmlContent: '<p>Your trip is confirmed!</p>',
      });

      expect(res.jobId).toContain('email-customer@drivego.in');
      expect(res.status).toBe('PROCESSED_MOCK');
    });

    it('dispatches Webhook asynchronous processing jobs', async () => {
      const res = await queueProducer.dispatchWebhookProcessing({
        event: 'payment.captured',
        payload: { paymentId: 'pay_123', amount: 5000 },
        receivedAt: new Date().toISOString(),
      });

      expect(res.jobId).toContain('webhook-payment.captured');
      expect(res.status).toBe('PROCESSED_MOCK');
    });

    it('dispatches Cleanup maintenance tasks', async () => {
      const res = await queueProducer.dispatchCleanupTask({
        task: 'PURGE_EXPIRED_OTPS',
      });

      expect(res.jobId).toContain('cleanup-PURGE_EXPIRED_OTPS');
      expect(res.status).toBe('PROCESSED_MOCK');
    });
  });
});
