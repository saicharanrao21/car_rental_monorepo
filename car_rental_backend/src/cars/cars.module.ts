import { Module } from '@nestjs/common';
import { CarsService } from './cars.service';
import { SearchRankingService } from './search-ranking.service';
import { VehicleAvailabilityService } from './vehicle-availability.service';
import { CarsController } from './cars.controller';
import { AuthModule } from '../auth/auth.module';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [AuthModule, JwtModule.register({})],
  controllers: [CarsController],
  providers: [CarsService, SearchRankingService, VehicleAvailabilityService],
  exports: [CarsService, SearchRankingService, VehicleAvailabilityService],
})
export class CarsModule {}
