import { Module } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { PricingController } from './pricing.controller';
import { CommonModule } from '../common/common.module';
import { CouponsModule } from '../coupons/coupons.module';
import { DepositsModule } from '../deposits/deposits.module';
import { LocationsModule } from '../locations/locations.module';
import { CarsModule } from '../cars/cars.module';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [
    CommonModule,
    CouponsModule,
    DepositsModule,
    LocationsModule,
    CarsModule,
    JwtModule.register({}),
    ConfigModule,
  ],
  controllers: [PricingController],
  providers: [PricingService],
  exports: [PricingService],
})
export class PricingModule {}
