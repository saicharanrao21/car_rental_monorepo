import { Module } from '@nestjs/common';
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

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
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
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
