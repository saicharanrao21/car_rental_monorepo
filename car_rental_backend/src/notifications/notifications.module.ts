import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';
import { SystemConfigModule } from '../config-engine/system-config.module';
import { QueuesModule } from '../queues/queues.module';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';
import { FcmService } from './fcm.service';
import { NotificationsService } from './notifications.service';
import { NotificationOrchestratorService } from './notification-orchestrator.service';
import { NotificationsController } from './notifications.controller';
import { NotificationRealtimeService } from './notification-realtime.service';
import { SmsProvider, MockSmsProvider } from './providers/sms-provider.service';
import { EmailProvider, MockEmailProvider } from './providers/email-provider.service';

@Global()
@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    AdminModule,
    SystemConfigModule,
    QueuesModule,
    WhatsAppModule,
  ],
  providers: [
    FcmService,
    NotificationsService,
    NotificationOrchestratorService,
    NotificationRealtimeService,
    { provide: SmsProvider, useClass: MockSmsProvider },
    { provide: EmailProvider, useClass: MockEmailProvider },
  ],
  controllers: [NotificationsController],
  exports: [
    NotificationsService,
    NotificationOrchestratorService,
    NotificationRealtimeService,
    FcmService,
    SmsProvider,
    EmailProvider,
  ],
})
export class NotificationsModule {}
