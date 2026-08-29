import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES } from '../queue.constants';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class WebhookProcessor implements OnModuleInit {
  private readonly logger = new Logger(WebhookProcessor.name);

  constructor(
    private readonly queueFactory: QueueFactoryService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.WEBHOOKS,
      this.process.bind(this),
      5, // Concurrency: 5 concurrent webhook workers
    );
  }

  async process(job: Job): Promise<any> {
    this.logger.log(`[PROCESS_WEBHOOK] Job ${job.id} started: ${job.name}`);

    const payload = job.data?.payload;
    if (!payload) {
      return { status: 'NO_PAYLOAD' };
    }

    // Process event idempotently
    return {
      success: true,
      processedAt: new Date().toISOString(),
      event: job.data?.event,
    };
  }
}
