import { Injectable, Logger } from '@nestjs/common';
import { QueueFactoryService } from './queue-factory.service';
import { QUEUE_NAMES, JOB_TYPES } from './queue.constants';

export interface SmsNotificationJobData {
  phone: string;
  message: string;
  otpCode?: string;
  correlationId?: string;
}

export interface EmailNotificationJobData {
  to: string;
  subject: string;
  htmlContent: string;
  bookingId?: string;
}

export interface WebhookJobData {
  event: string;
  payload: any;
  signature?: string;
  receivedAt: string;
}

export interface CleanupJobData {
  task: 'PURGE_EXPIRED_OTPS' | 'EXPIRE_STALE_BOOKINGS';
  olderThanDate?: string;
}

@Injectable()
export class QueueProducerService {
  private readonly logger = new Logger(QueueProducerService.name);

  constructor(private readonly queueFactory: QueueFactoryService) {}

  /**
   * Enqueues an SMS notification task.
   */
  async dispatchSmsNotification(data: SmsNotificationJobData) {
    const jobId = `sms-${data.phone}-${Date.now()}`;
    return this.queueFactory.addJob(
      QUEUE_NAMES.NOTIFICATIONS,
      JOB_TYPES.NOTIFICATIONS.SEND_SMS,
      data,
      { jobId },
    );
  }

  /**
   * Enqueues an Email notification task.
   */
  async dispatchEmailNotification(data: EmailNotificationJobData) {
    const jobId = `email-${data.to}-${Date.now()}`;
    return this.queueFactory.addJob(
      QUEUE_NAMES.NOTIFICATIONS,
      JOB_TYPES.NOTIFICATIONS.SEND_EMAIL,
      data,
      { jobId },
    );
  }

  /**
   * Enqueues an incoming Razorpay webhook for asynchronous processing.
   */
  async dispatchWebhookProcessing(data: WebhookJobData) {
    const jobId = `webhook-${data.event}-${Date.now()}`;
    return this.queueFactory.addJob(
      QUEUE_NAMES.WEBHOOKS,
      JOB_TYPES.WEBHOOKS.PROCESS_RAZORPAY_PAYMENT,
      data,
      { jobId },
    );
  }

  /**
   * Enqueues a maintenance cleanup task.
   */
  async dispatchCleanupTask(data: CleanupJobData) {
    const jobId = `cleanup-${data.task}-${Date.now()}`;
    return this.queueFactory.addJob(
      QUEUE_NAMES.CLEANUP,
      JOB_TYPES.CLEANUP.PURGE_EXPIRED_OTPS,
      data,
      { jobId },
    );
  }

  /**
   * Enqueues an analytics event for asynchronous batch processing.
   */
  async dispatchAnalyticsEvent(data: any) {
    const jobId = data.idempotencyKey || `analytics-${Date.now()}-${Math.random().toString(36).substring(7)}`;
    return this.queueFactory.addJob(
      QUEUE_NAMES.ANALYTICS,
      JOB_TYPES.ANALYTICS.TRACK_EVENT,
      data,
      { jobId },
    );
  }
}
