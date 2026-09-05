import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { VendorsModule } from './vendors/vendors.module';
import { CarsModule } from './cars/cars.module';
import { CommonModule } from './common/common.module';
import { BookingsModule } from './bookings/bookings.module';
import { ReviewsModule } from './reviews/reviews.module';
import { PaymentsModule } from './payments/payments.module';
import { UploadsModule } from './uploads/uploads.module';
import { PayoutsModule } from './payouts/payouts.module';
import { AdminModule } from './admin/admin.module';
import { NotificationsModule } from './notifications/notifications.module';
import { BannersModule } from './banners/banners.module';
import { WishlistModule } from './wishlist/wishlist.module';
import { RecentlyViewedModule } from './recently-viewed/recently-viewed.module';
import { DisputesModule } from './disputes/disputes.module';
import { SupportedCitiesModule } from './supported-cities/supported-cities.module';
import { DepositsModule } from './deposits/deposits.module';
import { DamageClaimsModule } from './damage-claims/damage-claims.module';
import { CouponsModule } from './coupons/coupons.module';
import { KycModule } from './kyc/kyc.module';
import { InvoicesModule } from './invoices/invoices.module';
import { SupportTicketsModule } from './support/support-tickets.module';
import { EmergencyAssistanceModule } from './emergency/emergency-assistance.module';
import { ProtectionPackagesModule } from './protection/protection-packages.module';
import { WalletsModule } from './wallets/wallets.module';
import { ReferralsModule } from './referrals/referrals.module';
import { LoyaltyModule } from './loyalty/loyalty.module';
import { FraudModule } from './fraud/fraud.module';
import { LocationsModule } from './locations/locations.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';
import { GrowthModule } from './growth/growth.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { QueuesModule } from './queues/queues.module';
import { SystemConfigModule } from './config-engine/system-config.module';
import { GeospatialModule } from './geospatial/geospatial.module';
import { PricingModule } from './pricing/pricing.module';
import { CorrelationIdMiddleware } from './common/correlation-id.middleware';

import { ScheduleModule } from '@nestjs/schedule';
import { validateEnv } from './common/env.validation';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
    }),
    ScheduleModule.forRoot(),
    PrismaModule,
    RedisModule,
    QueuesModule,
    SystemConfigModule,
    GeospatialModule,
    AuthModule,
    UsersModule,
    VendorsModule,
    CarsModule,
    CommonModule,
    BookingsModule,
    ReviewsModule,
    PaymentsModule,
    UploadsModule,
    PayoutsModule,
    AdminModule,
    NotificationsModule,
    BannersModule,
    WishlistModule,
    RecentlyViewedModule,
    DisputesModule,
    SupportedCitiesModule,
    DepositsModule,
    DamageClaimsModule,
    CouponsModule,
    KycModule,
    InvoicesModule,
    SupportTicketsModule,
    EmergencyAssistanceModule,
    ProtectionPackagesModule,
    WalletsModule,
    ReferralsModule,
    LoyaltyModule,
    FraudModule,
    LocationsModule,
    WhatsAppModule,
    GrowthModule,
    AnalyticsModule,
    PricingModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(CorrelationIdMiddleware).forRoutes('*');
  }
}
