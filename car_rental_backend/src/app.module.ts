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
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(CorrelationIdMiddleware).forRoutes('*');
  }
}
