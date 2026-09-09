import { Injectable, Logger, OnModuleDestroy, NotFoundException, BadRequestException } from '@nestjs/common';
import { ScheduledJob, ScheduleType } from './operations-domain.types';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';

@Injectable()
export class SchedulingEngineService implements OnModuleDestroy {
  private readonly logger = new Logger(SchedulingEngineService.name);

  // In-memory job registry: jobId -> ScheduledJob
  private readonly jobs = new Map<string, ScheduledJob>();
  private tickerInterval: NodeJS.Timeout | null = null;

  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly auditTracer: OperationsAuditTracerService,
  ) {
    // Start periodic ticker every 10 seconds
    this.tickerInterval = setInterval(() => this.tick(), 10 * 1000);
    if (this.tickerInterval.unref) {
      this.tickerInterval.unref();
    }
  }

  onModuleDestroy() {
    if (this.tickerInterval) {
      clearInterval(this.tickerInterval);
      this.tickerInterval = null;
    }
  }

  /**
   * Schedule a new background job (one-time, recurring, or cron).
   */
  public async scheduleJob(params: {
    name: string;
    scheduleType: ScheduleType;
    cronExpression?: string;
    scheduledTime: string;
    payload: Record<string, any>;
    actionType: string;
    timezone?: string;
    maxRetries?: number;
  }): Promise<ScheduledJob> {
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const job: ScheduledJob = {
      jobId,
      name: params.name,
      scheduleType: params.scheduleType,
      cronExpression: params.cronExpression,
      scheduledTime: params.scheduledTime,
      payload: params.payload,
      actionType: params.actionType,
      status: 'SCHEDULED',
      timezone: params.timezone || 'Asia/Kolkata',
      retryCount: 0,
      maxRetries: params.maxRetries ?? 3,
      createdAt: new Date().toISOString(),
    };

    this.jobs.set(jobId, job);
    this.logger.log(`[JOB_SCHEDULED] Job ${jobId} (${job.name}) scheduled for ${job.scheduledTime}`);

    this.auditTracer.recordActivity({
      correlationId: params.payload?.correlationId || jobId,
      sourceDomain: 'WORKFLOW',
      activity: `Scheduled job created: ${job.name} (${job.scheduleType})`,
      status: 'INFO',
      details: { jobId, scheduledTime: job.scheduledTime, actionType: job.actionType },
    });

    return job;
  }

  /**
   * Cancel a scheduled job.
   */
  public cancelJob(jobId: string): ScheduledJob {
    const job = this.jobs.get(jobId);
    if (!job) {
      throw new NotFoundException(`Job with ID ${jobId} not found`);
    }
    if (job.status === 'COMPLETED' || job.status === 'CANCELLED') {
      throw new BadRequestException(`Job ${jobId} is already ${job.status}`);
    }

    job.status = 'CANCELLED';
    this.logger.log(`[JOB_CANCELLED] Job ${jobId} (${job.name}) cancelled.`);
    return job;
  }

  /**
   * List all scheduled jobs with optional status filter.
   */
  public listJobs(status?: 'SCHEDULED' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'CANCELLED'): ScheduledJob[] {
    let list = Array.from(this.jobs.values());
    if (status) {
      list = list.filter((j) => j.status === status);
    }
    return list.sort((a, b) => new Date(b.scheduledTime).getTime() - new Date(a.scheduledTime).getTime());
  }

  /**
   * Manually trigger/execute a job immediately.
   */
  public async executeJobNow(jobId: string): Promise<ScheduledJob> {
    const job = this.jobs.get(jobId);
    if (!job) {
      throw new NotFoundException(`Job with ID ${jobId} not found`);
    }
    await this.processJob(job);
    return job;
  }

  /**
   * Scheduler ticker: evaluates due jobs and executes them.
   */
  private async tick(): Promise<void> {
    const now = new Date();

    for (const job of this.jobs.values()) {
      if (job.status !== 'SCHEDULED') continue;

      const dueTime = new Date(job.scheduledTime);
      if (dueTime <= now) {
        await this.processJob(job);
      }
    }
  }

  private async processJob(job: ScheduledJob): Promise<void> {
    job.status = 'RUNNING';
    this.logger.log(`[JOB_RUNNING] Executing scheduled job: ${job.name} (${job.jobId})`);

    try {
      // Dispatch as a domain event so downstream handlers (workflows, notifications) can react
      await this.eventBus.emit({
        eventType: `SCHEDULED_${job.actionType}`,
        aggregateType: 'SYSTEM',
        aggregateId: job.jobId,
        payload: {
          jobId: job.jobId,
          name: job.name,
          ...job.payload,
        },
        correlationId: job.payload?.correlationId || job.jobId,
      });

      job.status = 'COMPLETED';
      job.lastExecutedAt = new Date().toISOString();
      this.logger.log(`[JOB_COMPLETED] Job ${job.jobId} (${job.name}) finished successfully.`);

      // If RECURRING, reschedule next occurrence
      if (job.scheduleType === ScheduleType.RECURRING) {
        const nextTime = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(); // Default +24h
        job.scheduledTime = nextTime;
        job.status = 'SCHEDULED';
        this.logger.log(`[JOB_RESCHEDULED] Recurring job ${job.jobId} rescheduled to ${nextTime}`);
      }
    } catch (err: any) {
      this.logger.error(`[JOB_FAILED] Job ${job.jobId} failed: ${err.message}`, err.stack);
      job.retryCount += 1;

      if (job.retryCount <= job.maxRetries) {
        // Reschedule with backoff
        const backoffMs = Math.pow(2, job.retryCount) * 30 * 1000;
        job.scheduledTime = new Date(Date.now() + backoffMs).toISOString();
        job.status = 'SCHEDULED';
        this.logger.warn(`[JOB_RETRY] Rescheduled job ${job.jobId} for retry ${job.retryCount}/${job.maxRetries} in ${backoffMs / 1000}s`);
      } else {
        job.status = 'FAILED';
        this.logger.error(`[JOB_DEAD_LETTER] Job ${job.jobId} reached max retries and moved to FAILED.`);
      }
    }
  }
}
