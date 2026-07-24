import { Module } from '@nestjs/common';
import { VendorsService } from './vendors.service';
import { VendorsController } from './vendors.controller';
import { AdminVendorsController } from './admin-vendors.controller';
import { LocalitiesController } from './localities.controller';
import { AuthModule } from '../auth/auth.module';
import { JwtModule } from '@nestjs/jwt';
import { CarsModule } from '../cars/cars.module';

@Module({
  imports: [
    AuthModule,
    JwtModule.register({}),
    CarsModule,
  ],
  controllers: [VendorsController, AdminVendorsController, LocalitiesController],
  providers: [VendorsService],
  exports: [VendorsService],
})
export class VendorsModule {}
