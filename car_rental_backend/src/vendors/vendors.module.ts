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

import { VendorOnboardingController } from './onboarding/vendor-onboarding.controller';
import { AdminVendorOnboardingController } from './onboarding/admin-vendor-onboarding.controller';
import { VendorOnboardingRequirementsService } from './onboarding/vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from './onboarding/vendor-security-deposit.service';
import { VendorOnboardingEligibilityService } from './onboarding/vendor-onboarding-eligibility.service';

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
    VendorOnboardingController,
    AdminVendorOnboardingController,
  ],
  providers: [
    VendorsService,
    VendorOnboardingRequirementsService,
    VendorSecurityDepositService,
    VendorOnboardingEligibilityService,
  ],
  exports: [
    VendorsService,
    VendorOnboardingRequirementsService,
    VendorSecurityDepositService,
    VendorOnboardingEligibilityService,
  ],
})
export class VendorsModule {}
