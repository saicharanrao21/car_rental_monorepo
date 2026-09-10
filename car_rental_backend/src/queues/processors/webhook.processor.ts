import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES } from '../queue.constants';
import { PrismaService } from '../../prisma/prisma.service';
import { PaymentsService } from '../../payments/payments.service';
import { PayoutsService } from '../../payouts/payouts.service';

@Injectable()
export class WebhookProcessor implements OnModuleInit {
  private readonly logger = new Logger(WebhookProcessor.name);
  private paymentsService?: PaymentsService;
  private payoutsService?: PayoutsService;

  constructor(
    private readonly queueFactory: QueueFactoryService,
    private readonly prisma: PrismaService,
    private readonly moduleRef: ModuleRef,
  ) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.WEBHOOKS,
      this.process.bind(this),
      5, // Concurrency: 5 concurrent webhook workers
    );
  }

  private getPaymentsService(): PaymentsService | null {
    if (!this.paymentsService) {
      try {
        this.paymentsService = this.moduleRef.get(PaymentsService, {
          strict: false,
        });
      } catch {
        this.paymentsService = undefined;
      }
    }
    return this.paymentsService || null;
  }

  private getPayoutsService(): PayoutsService | null {
    if (!this.payoutsService) {
      try {
        this.payoutsService = this.moduleRef.get(PayoutsService, {
          strict: false,
        });
      } catch {
        this.payoutsService = undefined;
      }
    }
    return this.payoutsService || null;
  }

  async process(job: Job): Promise<any> {
    this.logger.log(`[PROCESS_WEBHOOK] Job ${job.id} started: ${job.name}`);

    const rawBody =
      job.data?.rawBody ||
      (typeof job.data?.payload === 'string'
        ? job.data?.payload
        : JSON.stringify(job.data?.payload || {}));
    const signature = job.data?.signature || '';
    const headers = job.data?.headers || {};
    const event = job.data?.event || job.data?.payload?.event;

    if (!rawBody || rawBody === '{}') {
      return { status: 'NO_PAYLOAD' };
    }

    try {
      // Check if this is a payout webhook event or standard payment webhook event
      const isPayoutEvent =
        job.name === 'payout_webhook' ||
        job.data?.type === 'PAYOUT' ||
        (typeof event === 'string' && event.startsWith('payout.'));

      if (isPayoutEvent) {
        const payouts = this.getPayoutsService();
        if (payouts) {
          return await payouts.handlePayoutWebhook(rawBody, signature, headers);
        }
      } else {
        const payments = this.getPaymentsService();
        if (payments) {
          return await payments.handleWebhook(rawBody, signature, headers);
        }
      }

      return {
        success: true,
        processedAt: new Date().toISOString(),
        event,
      };
    } catch (err: any) {
      this.logger.error(
        `[PROCESS_WEBHOOK_ERROR] Job ${job.id} execution failed: ${err.message}`,
        err.stack,
      );
      throw err;
    }
  }
}
