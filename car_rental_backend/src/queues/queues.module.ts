import { Module, Global } from '@nestjs/common';
import { QueueFactoryService } from './queue-factory.service';
import { QueueProducerService } from './queue-producer.service';
import { NotificationProcessor } from './processors/notification.processor';
import { WebhookProcessor } from './processors/webhook.processor';
import { CleanupProcessor } from './processors/cleanup.processor';

@Global()
@Module({
  providers: [
    QueueFactoryService,
    QueueProducerService,
    NotificationProcessor,
    WebhookProcessor,
    CleanupProcessor,
  ],
  exports: [QueueFactoryService, QueueProducerService],
})
export class QueuesModule {}
export * from './queue.constants';
export * from './queue-factory.service';
export * from './queue-producer.service';
