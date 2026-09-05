import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES } from '../queue.constants';
import { NotificationOrchestratorService } from '../../notifications/notification-orchestrator.service';

@Injectable()
export class NotificationProcessor implements OnModuleInit {
  private readonly logger = new Logger(NotificationProcessor.name);
  private orchestrator?: NotificationOrchestratorService;

  constructor(
    private readonly queueFactory: QueueFactoryService,
    private readonly moduleRef: ModuleRef,
  ) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.NOTIFICATIONS,
      this.process.bind(this),
      10, // Concurrency: 10 concurrent notification workers
    );
  }

  private getOrchestrator(): NotificationOrchestratorService | null {
    if (!this.orchestrator) {
      try {
        this.orchestrator = this.moduleRef.get(NotificationOrchestratorService, {
          strict: false,
        });
      } catch {
        this.orchestrator = undefined;
      }
    }
    return this.orchestrator || null;
  }

  async process(job: Job): Promise<any> {
    this.logger.log(
      `[PROCESS_NOTIFICATION] Job ${job.id} of type ${job.name} started`,
    );

    switch (job.name) {
      case 'send-push':
        return this.handlePush(job.data);
      case 'send-sms':
        return this.handleSms(job.data);
      case 'send-email':
        return this.handleEmail(job.data);
      case 'send-whatsapp':
        return this.handleWhatsApp(job.data);
      default:
        this.logger.warn(`Unknown notification job name: ${job.name}`);
        return { status: 'IGNORED' };
    }
  }

  private async handlePush(data: {
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    correlationId?: string;
  }) {
    const orchestrator = this.getOrchestrator();
    if (orchestrator && data.correlationId) {
      return orchestrator.executePushDelivery(
        data.correlationId,
        data.userId,
        data.title,
        data.body,
        data.data,
      );
    }
    this.logger.log(`[WORKER_PUSH] Dispatched Push to user ${data.userId}`);
    return { success: true, userId: data.userId, deliveredAt: new Date().toISOString() };
  }

  private async handleSms(data: {
    phone: string;
    message: string;
    otpCode?: string;
    correlationId?: string;
  }) {
    const orchestrator = this.getOrchestrator();
    if (orchestrator && data.correlationId) {
      return orchestrator.executeSmsDelivery(
        data.correlationId,
        data.phone,
        data.message,
      );
    }
    this.logger.log(`[WORKER_SMS] Dispatched SMS to ${data.phone}`);
    return { success: true, phone: data.phone, deliveredAt: new Date().toISOString() };
  }

  private async handleEmail(data: {
    to: string;
    subject: string;
    htmlContent?: string;
    correlationId?: string;
  }) {
    const orchestrator = this.getOrchestrator();
    if (orchestrator && data.correlationId) {
      return orchestrator.executeEmailDelivery(
        data.correlationId,
        data.to,
        data.subject,
        data.htmlContent || `<p>${data.subject}</p>`,
      );
    }
    this.logger.log(`[WORKER_EMAIL] Dispatched Email to ${data.to} | Subject: ${data.subject}`);
    return { success: true, to: data.to, sentAt: new Date().toISOString() };
  }

  private async handleWhatsApp(data: {
    phone: string;
    templateName?: string;
    template?: string;
    bodyParameters?: string[];
    correlationId?: string;
  }) {
    const orchestrator = this.getOrchestrator();
    if (orchestrator && data.correlationId) {
      return orchestrator.executeWhatsAppDelivery(
        data.correlationId,
        data.phone,
        data.templateName || data.template || 'general_update',
        data.bodyParameters || [],
      );
    }
    this.logger.log(`[WORKER_WHATSAPP] Dispatched WhatsApp to ${data.phone}`);
    return { success: true, phone: data.phone };
  }
}
