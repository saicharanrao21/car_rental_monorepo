import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES } from '../queue.constants';

@Injectable()
export class NotificationProcessor implements OnModuleInit {
  private readonly logger = new Logger(NotificationProcessor.name);

  constructor(private readonly queueFactory: QueueFactoryService) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.NOTIFICATIONS,
      this.process.bind(this),
      10, // Concurrency: 10 concurrent notification workers
    );
  }

  async process(job: Job): Promise<any> {
    this.logger.log(
      `[PROCESS_NOTIFICATION] Job ${job.id} of type ${job.name} started`,
    );

    switch (job.name) {
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

  private async handleSms(data: { phone: string; message: string; otpCode?: string }) {
    this.logger.log(`[WORKER_SMS] Dispatched SMS to ${data.phone}`);
    return { success: true, phone: data.phone, deliveredAt: new Date().toISOString() };
  }

  private async handleEmail(data: { to: string; subject: string }) {
    this.logger.log(`[WORKER_EMAIL] Dispatched Email to ${data.to} | Subject: ${data.subject}`);
    return { success: true, to: data.to, sentAt: new Date().toISOString() };
  }

  private async handleWhatsApp(data: { phone: string; template: string }) {
    this.logger.log(`[WORKER_WHATSAPP] Dispatched WhatsApp to ${data.phone}`);
    return { success: true, phone: data.phone };
  }
}
