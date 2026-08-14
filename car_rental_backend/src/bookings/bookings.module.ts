import { Module } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { CancellationPolicyService } from './cancellation-policy.service';
import { CommonModule } from '../common/common.module';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [CommonModule, PaymentsModule],
  controllers: [BookingsController],
  providers: [BookingsService, CancellationPolicyService],
  exports: [BookingsService, CancellationPolicyService],
})
export class BookingsModule {}
