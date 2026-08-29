import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  Inject,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue, Worker, Job, Processor } from 'bullmq';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { QUEUE_NAMES, DEFAULT_JOB_OPTIONS } from './queue.constants';

@Injectable()
export class QueueFactoryService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(QueueFactoryService.name);
  private readonly queues = new Map<string, Queue>();
  private readonly workers = new Map<string, Worker>();
  private readonly isMockMode: boolean;
  private readonly redisUrl: string;

  constructor(
    private readonly configService: ConfigService,
    @Inject(REDIS_CLIENT) private readonly redisClient: Redis,
  ) {
    this.isMockMode =
      this.configService.get<string>('REDIS_USE_MOCK') === 'true';
    this.redisUrl =
      this.configService.get<string>('REDIS_URL') || 'redis://localhost:6379';
  }

  onModuleInit() {
    if (this.isMockMode) {
      this.logger.log(
        'QueueFactoryService: Operating in Mock/Direct-Execution mode for testing/local dev.',
      );
      return;
    }

    try {
      // Initialize core BullMQ queues
      for (const queueName of Object.values(QUEUE_NAMES)) {
        this.getOrCreateQueue(queueName);
      }
      this.logger.log('QueueFactoryService: BullMQ queues initialized successfully.');
    } catch (err: any) {
      this.logger.error(
        `Failed to initialize BullMQ queues: ${err?.message}`,
        err?.stack,
      );
    }
  }

  async onModuleDestroy() {
    this.logger.log('Shutting down BullMQ workers and queues gracefully...');

    // 1. Close all active workers first
    for (const [name, worker] of this.workers.entries()) {
      try {
        await worker.close();
        this.logger.log(`Worker closed: [${name}]`);
      } catch (err: any) {
        this.logger.warn(`Error closing worker [${name}]: ${err?.message}`);
      }
    }
    this.workers.clear();

    // 2. Close all queues
    for (const [name, queue] of this.queues.entries()) {
      try {
        await queue.close();
        this.logger.log(`Queue closed: [${name}]`);
      } catch (err: any) {
        this.logger.warn(`Error closing queue [${name}]: ${err?.message}`);
      }
    }
    this.queues.clear();
  }

  /**
   * Returns or creates a BullMQ Queue instance connected to Redis.
   */
  getOrCreateQueue(queueName: string): Queue | null {
    if (this.isMockMode) {
      return null;
    }

    if (this.queues.has(queueName)) {
      return this.queues.get(queueName)!;
    }

    try {
      const connection = new Redis(this.redisUrl, {
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
      });

      const queue = new Queue(queueName, {
        connection,
        defaultJobOptions: DEFAULT_JOB_OPTIONS,
      });

      this.queues.set(queueName, queue);
      return queue;
    } catch (err: any) {
      this.logger.error(
        `Failed to instantiate BullMQ queue [${queueName}]: ${err?.message}`,
      );
      return null;
    }
  }

  /**
   * Registers a BullMQ worker processor with error tracking, retry policies, and structured logs.
   */
  registerWorker(
    queueName: string,
    processor: Processor,
    concurrency: number = 5,
  ): Worker | null {
    if (this.isMockMode) {
      this.logger.debug(
        `Mock mode: Skipping background worker daemon creation for [${queueName}]`,
      );
      return null;
    }

    if (this.workers.has(queueName)) {
      return this.workers.get(queueName)!;
    }

    try {
      const connection = new Redis(this.redisUrl, {
        maxRetriesPerRequest: null,
        enableReadyCheck: false,
      });

      const worker = new Worker(queueName, processor, {
        connection,
        concurrency,
      });

      worker.on('completed', (job: Job) => {
        this.logger.log(
          `[JOB_SUCCESS] Queue: ${queueName} | JobId: ${job.id} | Name: ${job.name}`,
        );
      });

      worker.on('failed', (job: Job | undefined, err: Error) => {
        this.logger.error(
          `[JOB_FAILED] Queue: ${queueName} | JobId: ${job?.id} | Name: ${job?.name} | Error: ${err.message}`,
          err.stack,
        );
      });

      this.workers.set(queueName, worker);
      this.logger.log(
        `Registered BullMQ worker for [${queueName}] with concurrency=${concurrency}`,
      );
      return worker;
    } catch (err: any) {
      this.logger.error(
        `Failed to register BullMQ worker for [${queueName}]: ${err?.message}`,
      );
      return null;
    }
  }

  /**
   * Dispatches a job to a BullMQ queue or processes immediately if in mock mode.
   */
  async addJob<T>(
    queueName: string,
    jobName: string,
    data: T,
    opts?: { jobId?: string; delay?: number; priority?: number },
  ): Promise<{ jobId: string; status: 'QUEUED' | 'PROCESSED_MOCK' }> {
    const queue = this.getOrCreateQueue(queueName);

    if (!queue || this.isMockMode) {
      this.logger.log(
        `[MOCK_JOB_DISPATCH] Queue: ${queueName} | Job: ${jobName} | Data: ${JSON.stringify(
          data,
        )}`,
      );
      return {
        jobId: opts?.jobId || `mock-${Date.now()}`,
        status: 'PROCESSED_MOCK',
      };
    }

    const job = await queue.add(jobName, data, {
      jobId: opts?.jobId,
      delay: opts?.delay,
      priority: opts?.priority,
    });

    return {
      jobId: job.id || 'unknown',
      status: 'QUEUED',
    };
  }
}
