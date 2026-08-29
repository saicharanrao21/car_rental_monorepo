import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES } from '../queue.constants';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class CleanupProcessor implements OnModuleInit {
  private readonly logger = new Logger(CleanupProcessor.name);

  constructor(
    private readonly queueFactory: QueueFactoryService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.CLEANUP,
      this.process.bind(this),
      1, // Single concurrency for cleanup jobs
    );
  }

  async process(job: Job): Promise<any> {
    this.logger.log(`[PROCESS_CLEANUP] Job ${job.id} task: ${job.name}`);

    if (job.name === 'purge-expired-otps') {
      const deleted = await this.prisma.otpRequest.deleteMany({
        where: {
          expiresAt: { lt: new Date(Date.now() - 3600 * 1000) }, // Expired over 1 hour ago
        },
      });
      this.logger.log(`[CLEANUP_OTP] Purged ${deleted.count} expired OTP records`);
      return { purgedOtps: deleted.count };
    }

    return { status: 'NOOP' };
  }
}
