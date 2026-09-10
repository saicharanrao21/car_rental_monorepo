import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { OutboxWorkerService } from '../outbox-worker.service';
import { BookingOutboxService } from '../booking-outbox.service';

describe('Phase P: Durable Transactional Outbox Worker', () => {
  let worker: OutboxWorkerService;
  let mockPrisma: any;
  let mockOutboxService: any;
  let outboxStore: any[] = [];

  beforeEach(async () => {
    outboxStore = [
      {
        id: 'outbox_1',
        bookingId: 'bk_1',
        eventType: 'BOOKING_CONFIRMED',
        status: 'PENDING',
        retryCount: 0,
        maxRetries: 3,
        updatedAt: new Date(),
        createdAt: new Date(Date.now() - 5000),
      },
      {
        id: 'outbox_2',
        bookingId: 'bk_2',
        eventType: 'BOOKING_CANCELLED',
        status: 'FAILED',
        retryCount: 1,
        maxRetries: 3,
        updatedAt: new Date(Date.now() - 10000), // Beyond exponential backoff (2s)
        createdAt: new Date(Date.now() - 20000),
      },
      {
        id: 'outbox_3',
        bookingId: 'bk_3',
        eventType: 'TRIP_STARTED',
        status: 'FAILED',
        retryCount: 1,
        updatedAt: new Date(), // Within exponential backoff delay!
        createdAt: new Date(),
        maxRetries: 3,
      },
    ];

    mockOutboxService = {
      dispatchEvent: jest.fn().mockImplementation(async (id: string) => {
        const ev = outboxStore.find((e) => e.id === id);
        if (ev) {
          if (ev.id === 'outbox_fail') {
            ev.status = 'FAILED';
            ev.retryCount++;
            return false;
          }
          ev.status = 'PUBLISHED';
          return true;
        }
        return false;
      }),
    };

    mockPrisma = {
      bookingOutboxEvent: {
        findMany: jest.fn().mockImplementation(async ({ where }) => {
          let results = [...outboxStore];
          if (where?.status === 'PROCESSING' && where?.updatedAt?.lt) {
            return results.filter(
              (e) => e.status === 'PROCESSING' && e.updatedAt < where.updatedAt.lt,
            );
          }
          if (where?.OR) {
            return results.filter(
              (e) => e.status === 'PENDING' || (e.status === 'FAILED' && e.retryCount < 5),
            );
          }
          return results;
        }),
        findUnique: jest.fn().mockImplementation(async ({ where }) => {
          return outboxStore.find((e) => e.id === where.id) || null;
        }),
        updateMany: jest.fn().mockImplementation(async ({ where, data }) => {
          let count = 0;
          for (const e of outboxStore) {
            if (e.id === where.id && where.status.in.includes(e.status)) {
              Object.assign(e, data);
              count++;
            }
          }
          return { count };
        }),
        update: jest.fn().mockImplementation(async ({ where, data }) => {
          const ev = outboxStore.find((e) => e.id === where.id);
          if (ev) {
            Object.assign(ev, data);
          }
          return ev;
        }),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OutboxWorkerService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: BookingOutboxService, useValue: mockOutboxService },
      ],
    }).compile();

    worker = module.get<OutboxWorkerService>(OutboxWorkerService);
  });

  it('should claim and process PENDING outbox events atomically', async () => {
    const result = await worker.processPendingEvents(10);

    expect(result.processedCount).toBeGreaterThanOrEqual(1);
    expect(result.successCount).toBeGreaterThanOrEqual(1);

    // outbox_1 was PENDING and should now be PUBLISHED
    const ev1 = outboxStore.find((e) => e.id === 'outbox_1');
    expect(ev1.status).toBe('PUBLISHED');
  });

  it('should process retryable FAILED events after exponential backoff has elapsed', async () => {
    await worker.processPendingEvents(10);

    // outbox_2 was FAILED with updatedAt 10s ago, which exceeds backoff (2^1 * 1000 = 2s)
    const ev2 = outboxStore.find((e) => e.id === 'outbox_2');
    expect(ev2.status).toBe('PUBLISHED');
  });

  it('should skip FAILED events that are still within exponential backoff delay window', async () => {
    await worker.processPendingEvents(10);

    // outbox_3 updatedAt was now, so backoff has not elapsed
    const ev3 = outboxStore.find((e) => e.id === 'outbox_3');
    expect(ev3.status).toBe('FAILED');
    expect(ev3.retryCount).toBe(1);
  });

  it('should dead-letter events exceeding maximum retry attempts', async () => {
    outboxStore.push({
      id: 'outbox_max_retry',
      bookingId: 'bk_dead',
      eventType: 'BOOKING_EXPIRED',
      status: 'FAILED',
      retryCount: 2,
      maxRetries: 3,
      updatedAt: new Date(Date.now() - 30000),
      createdAt: new Date(Date.now() - 60000),
    });

    mockOutboxService.dispatchEvent.mockImplementation(async (id: string) => {
      const ev = outboxStore.find((e) => e.id === id);
      if (!ev) return false;
      if (id === 'outbox_max_retry') {
        ev.retryCount = 3;
        ev.status = 'DEAD_LETTER';
        return false;
      }
      ev.status = 'PUBLISHED';
      return true;
    });

    const result = await worker.processPendingEvents(10);
    expect(result.deadLetterCount).toBeGreaterThanOrEqual(1);

    const deadEv = outboxStore.find((e) => e.id === 'outbox_max_retry');
    expect(deadEv.status).toBe('DEAD_LETTER');
  });

  it('should recover stale events left in PROCESSING state after node crashes or restarts', async () => {
    outboxStore.push({
      id: 'outbox_crashed',
      bookingId: 'bk_crash',
      eventType: 'BOOKING_CREATED',
      status: 'PROCESSING',
      retryCount: 0,
      maxRetries: 3,
      updatedAt: new Date(Date.now() - 400000), // 6+ minutes ago (stale)
      createdAt: new Date(Date.now() - 450000),
    });

    const recovered = await worker.recoverStaleProcessingEvents(300000);
    expect(recovered).toBe(1);

    const crashedEv = outboxStore.find((e) => e.id === 'outbox_crashed');
    expect(crashedEv.status).toBe('FAILED');
    expect(crashedEv.retryCount).toBe(1);
    expect(crashedEv.lastError).toContain('Worker timeout recovery');
  });
});
