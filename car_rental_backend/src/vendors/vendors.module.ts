import { Module } from '@nestjs/common';
import { VendorsService } from './vendors.service';
import { VendorsController } from './vendors.controller';
import { AdminVendorsController } from './admin-vendors.controller';
import { LocalitiesController } from './localities.controller';
import { AuthModule } from '../auth/auth.module';
import { JwtModule } from '@nestjs/jwt';
import { CarsModule } from '../cars/cars.module';
import { CommonModule } from '../common/common.module';
import { UploadsModule } from '../uploads/uploads.module';

@Module({
  imports: [
    AuthModule,
    JwtModule.register({}),
    CarsModule,
    CommonModule,
    UploadsModule,
  ],
  controllers: [
    VendorsController,
    AdminVendorsController,
    LocalitiesController,
  ],
  providers: [VendorsService],
  exports: [VendorsService],
})
export class VendorsModule {}
