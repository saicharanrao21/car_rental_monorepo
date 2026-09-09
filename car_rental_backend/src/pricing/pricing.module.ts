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

import { RentalPricingResolutionService } from './rental-pricing-resolution.service';
import { DemandAwarePricingService } from './demand-aware-pricing.service';
import { CompetitivePricingService } from './competitive-pricing.service';

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
  providers: [
    PricingService,
    RentalPricingResolutionService,
    DemandAwarePricingService,
    CompetitivePricingService,
  ],
  exports: [
    PricingService,
    RentalPricingResolutionService,
    DemandAwarePricingService,
    CompetitivePricingService,
  ],
})
export class PricingModule {}
