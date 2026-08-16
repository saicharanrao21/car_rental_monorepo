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

@Module({
  imports: [CommonModule, PaymentsModule, UploadsModule, CouponsModule],
  controllers: [BookingsController],
  providers: [
    BookingsService,
    CancellationPolicyService,
    InspectionsService,
    HandoverOtpService,
  ],
  exports: [
    BookingsService,
    CancellationPolicyService,
    InspectionsService,
    HandoverOtpService,
  ],
})
export class BookingsModule {}

