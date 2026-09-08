import { Module } from '@nestjs/common';
import { CarsService } from './cars.service';
import { SearchRankingService } from './search-ranking.service';
import { VehicleAvailabilityService } from './vehicle-availability.service';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';
import { VehicleLifecycleService } from './vehicle-lifecycle.service';
import { VendorFleetService } from './vendor-fleet.service';
import { CarsController } from './cars.controller';
import { AdminFleetController } from './admin-fleet.controller';
import { VendorFleetController } from './vendor-fleet.controller';
import { AuthModule } from '../auth/auth.module';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [AuthModule, JwtModule.register({})],
  controllers: [CarsController, AdminFleetController, VendorFleetController],
  providers: [
    CarsService,
    SearchRankingService,
    VehicleAvailabilityService,
    VehicleOperationsEligibilityService,
    VehicleLifecycleService,
    VendorFleetService,
  ],
  exports: [
    CarsService,
    SearchRankingService,
    VehicleAvailabilityService,
    VehicleOperationsEligibilityService,
    VehicleLifecycleService,
    VendorFleetService,
  ],
})
export class CarsModule {}

