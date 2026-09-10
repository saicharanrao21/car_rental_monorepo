import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { BookingOutboxService } from './booking-outbox.service';

export interface OutboxWorkerResult {
  processedCount: number;
  successCount: number;
  failedCount: number;
  deadLetterCount: number;
  staleRecoveredCount: number;
}

@Injectable()
export class OutboxWorkerService {
  private readonly logger = new Logger(OutboxWorkerService.name);
  private isProcessing = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly outboxService: BookingOutboxService,
  ) {}

  /**
   * Periodic durable worker trigger running every 10 seconds.
   */
  @Cron(CronExpression.EVERY_10_SECONDS)
  async handleCron(): Promise<void> {
    if (this.isProcessing) {
      this.logger.debug('Previous outbox processing run still in progress. Skipping cycle.');
      return;
    }

    try {
      this.isProcessing = true;
      await this.processPendingEvents();
    } catch (err: any) {
      this.logger.error(`Error in outbox worker cron: ${err?.message}`, err?.stack);
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * Recovers events abandoned in 'PROCESSING' state if a server node crashed.
   */
  async recoverStaleProcessingEvents(timeoutMs = 300_000): Promise<number> {
    const cutoff = new Date(Date.now() - timeoutMs);
    const staleEvents = await this.prisma.bookingOutboxEvent.findMany({
      where: {
        status: 'PROCESSING',
        updatedAt: { lt: cutoff },
      },
      take: 50,
    });

    let recovered = 0;
    for (const ev of staleEvents) {
      const nextRetry = ev.retryCount + 1;
      const isDeadLetter = nextRetry >= ev.maxRetries;
      await this.prisma.bookingOutboxEvent.update({
        where: { id: ev.id },
        data: {
          status: isDeadLetter ? 'DEAD_LETTER' : 'FAILED',
          retryCount: nextRetry,
          lastError: 'Worker timeout recovery: process crashed or timed out during dispatch',
          updatedAt: new Date(),
        },
      });
      recovered++;
    }

    if (recovered > 0) {
      this.logger.warn(`Recovered ${recovered} stale PROCESSING outbox events.`);
    }
    return recovered;
  }

  /**
   * Main polling & processing loop with atomic claiming and exponential backoff.
   */
  async processPendingEvents(batchSize = 25): Promise<OutboxWorkerResult> {
    const result: OutboxWorkerResult = {
      processedCount: 0,
      successCount: 0,
      failedCount: 0,
      deadLetterCount: 0,
      staleRecoveredCount: 0,
    };

    // 1. Recover stale processing events from previous crash
    result.staleRecoveredCount = await this.recoverStaleProcessingEvents();

    const now = Date.now();

    // 2. Fetch candidates in PENDING or retryable FAILED state
    const candidates = await this.prisma.bookingOutboxEvent.findMany({
      where: {
        OR: [
          { status: 'PENDING' },
          {
            status: 'FAILED',
            retryCount: { lt: 5 }, // Within retry allowance
          },
        ],
      },
      orderBy: { createdAt: 'asc' },
      take: batchSize * 2,
    });

    if (!candidates || candidates.length === 0) {
      return result;
    }

    for (const event of candidates) {
      if (result.processedCount >= batchSize) {
        break;
      }

      // Check exponential backoff for FAILED events
      if (event.status === 'FAILED') {
        const backoffMs = Math.min(60_000, 1000 * Math.pow(2, event.retryCount));
        const lastUpdated = event.updatedAt ? new Date(event.updatedAt).getTime() : 0;
        if (now - lastUpdated < backoffMs) {
          // Still in backoff delay period
          continue;
        }
      }

      // 3. Atomically claim the event to prevent concurrent workers from processing it
      const claimResult = await this.prisma.bookingOutboxEvent.updateMany({
        where: {
          id: event.id,
          status: { in: ['PENDING', 'FAILED'] },
        },
        data: {
          status: 'PROCESSING',
          updatedAt: new Date(),
        },
      });

      if (claimResult.count === 0) {
        // Already claimed by another concurrent worker
        continue;
      }

      result.processedCount++;

      // 4. Dispatch the claimed event
      try {
        const dispatched = await this.outboxService.dispatchEvent(event.id);

        if (dispatched) {
          result.successCount++;
        } else {
          // dispatchEvent already records FAILED or DEAD_LETTER when it catches errors
          const updated = await this.prisma.bookingOutboxEvent.findUnique({
            where: { id: event.id },
            select: { status: true },
          });
          if (updated?.status === 'DEAD_LETTER') {
            result.deadLetterCount++;
          } else {
            result.failedCount++;
          }
        }
      } catch (dispatchErr: any) {
        this.logger.error(
          `Unexpected exception during outbox dispatch for ${event.id}: ${dispatchErr?.message}`,
        );
        const nextRetry = event.retryCount + 1;
        const isDeadLetter = nextRetry >= event.maxRetries;
        await this.prisma.bookingOutboxEvent.update({
          where: { id: event.id },
          data: {
            status: isDeadLetter ? 'DEAD_LETTER' : 'FAILED',
            retryCount: nextRetry,
            lastError: dispatchErr?.message || String(dispatchErr),
            updatedAt: new Date(),
          },
        });

        if (isDeadLetter) {
          result.deadLetterCount++;
        } else {
          result.failedCount++;
        }
      }
    }

    if (result.processedCount > 0) {
      this.logger.log(
        `[OUTBOX WORKER] Processed ${result.processedCount} events: ` +
        `${result.successCount} succeeded, ${result.failedCount} failed, ` +
        `${result.deadLetterCount} dead-lettered, ${result.staleRecoveredCount} stale-recovered.`,
      );
    }

    return result;
  }
}
