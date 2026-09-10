import { Module } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { CancellationPolicyService } from './cancellation-policy.service';
import { InspectionsService } from './inspections.service';
import { HandoverOtpService } from './handover-otp.service';
import { CommonModule } from '../common/common.module';
import { PaymentsModule } from '../payments/payments.module';
import { UploadsModule } from '../uploads/uploads.module';
import { CouponsModule } from '../coupons/coupons.module';
import { DepositsModule } from '../deposits/deposits.module';
import { InvoicesModule } from '../invoices/invoices.module';
import { ReferralsModule } from '../referrals/referrals.module';
import { LoyaltyModule } from '../loyalty/loyalty.module';
import { FraudModule } from '../fraud/fraud.module';
import { LocationsModule } from '../locations/locations.module';
import { CarsModule } from '../cars/cars.module';
import { PricingModule } from '../pricing/pricing.module';

import { TripExtensionsService } from './trip-extensions.service';
import { TripExtensionsController } from './trip-extensions.controller';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { BookingOutboxService } from './booking-outbox.service';
import { RentalOperationsService } from './rental-operations.service';
import { RentalAutomationService } from './rental-automation.service';
import { RentalCoreController } from './rental-core.controller';
import { FleetModule } from '../fleet/fleet.module';
import { forwardRef } from '@nestjs/common';

import { OutboxWorkerService } from './outbox-worker.service';

@Module({
  imports: [
    CommonModule,
    PaymentsModule,
    UploadsModule,
    CouponsModule,
    DepositsModule,
    InvoicesModule,
    ReferralsModule,
    LoyaltyModule,
    FraudModule,
    LocationsModule,
    CarsModule,
    PricingModule,
    forwardRef(() => FleetModule),
  ],
  controllers: [
    BookingsController,
    TripExtensionsController,
    RentalCoreController,
  ],
  providers: [
    BookingsService,
    BookingLifecycleService,
    BookingOutboxService,
    OutboxWorkerService,
    CancellationPolicyService,
    InspectionsService,
    HandoverOtpService,
    TripExtensionsService,
    RentalOperationsService,
    RentalAutomationService,
  ],
  exports: [
    BookingsService,
    BookingLifecycleService,
    BookingOutboxService,
    OutboxWorkerService,
    CancellationPolicyService,
    InspectionsService,
    HandoverOtpService,
    TripExtensionsService,
    RentalOperationsService,
    RentalAutomationService,
  ],
})
export class BookingsModule {}


