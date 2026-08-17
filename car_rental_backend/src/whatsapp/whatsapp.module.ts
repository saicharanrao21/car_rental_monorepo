import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminModule } from '../admin/admin.module';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppController } from './whatsapp.controller';
import { AdminWhatsAppController } from './admin-whatsapp.controller';
import {
  WhatsAppProvider,
  MetaWhatsAppProvider,
  MockWhatsAppProvider,
} from './whatsapp-provider.service';

@Module({
  imports: [PrismaModule, AdminModule, ConfigModule],
  controllers: [WhatsAppController, AdminWhatsAppController],
  providers: [
    WhatsAppService,
    MetaWhatsAppProvider,
    MockWhatsAppProvider,
    {
      provide: WhatsAppProvider,
      useFactory: (
        configService: ConfigService,
        metaProvider: MetaWhatsAppProvider,
        mockProvider: MockWhatsAppProvider,
      ) => {
        const isProd = configService.get<string>('NODE_ENV') === 'production';
        const hasToken = !!configService.get<string>('WHATSAPP_ACCESS_TOKEN');
        return isProd && hasToken ? metaProvider : mockProvider;
      },
      inject: [ConfigService, MetaWhatsAppProvider, MockWhatsAppProvider],
    },
  ],
  exports: [WhatsAppService, WhatsAppProvider],
})
export class WhatsAppModule {}
