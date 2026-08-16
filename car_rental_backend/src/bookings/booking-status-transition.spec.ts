import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CancellationPolicyService } from './cancellation-policy.service';
import { AuditLogService } from '../admin/audit-log.service';
import { HandoverOtpService } from './handover-otp.service';
import { CouponsService } from '../coupons/coupons.service';
import { BookingStatus } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';

describe('BookingsService — Status Transition Guard Tests', () => {
  let service: BookingsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: {} },
        { provide: BookingLockService, useValue: {} },
        { provide: CommissionResolverService, useValue: {} },
        { provide: FareCalculatorService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: CancellationPolicyService, useValue: {} },
        { provide: AuditLogService, useValue: {} },
        { provide: HandoverOtpService, useValue: {} },
        { provide: CouponsService, useValue: {} },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
  });

  it('1. Valid transition PENDING -> CONFIRMED succeeds', () => {
    expect(() =>
      service.validateStatusTransition(BookingStatus.PENDING, BookingStatus.CONFIRMED),
    ).not.toThrow();
  });

  it('2. Valid lifecycle PENDING -> CONFIRMED -> HANDOVER_READY -> ONGOING -> RETURN_PENDING -> COMPLETED succeeds', () => {
    expect(() =>
      service.validateStatusTransition(BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY),
    ).not.toThrow();
    expect(() =>
      service.validateStatusTransition(BookingStatus.HANDOVER_READY, BookingStatus.ONGOING),
    ).not.toThrow();
    expect(() =>
      service.validateStatusTransition(BookingStatus.ONGOING, BookingStatus.RETURN_PENDING),
    ).not.toThrow();
    expect(() =>
      service.validateStatusTransition(BookingStatus.RETURN_PENDING, BookingStatus.COMPLETED),
    ).not.toThrow();
  });

  it('3. Invalid transition PENDING -> COMPLETED throws BadRequestException', () => {
    expect(() =>
      service.validateStatusTransition(BookingStatus.PENDING, BookingStatus.COMPLETED),
    ).toThrow(BadRequestException);
  });

  it('4. Invalid transition CANCELLED -> ONGOING throws BadRequestException', () => {
    expect(() =>
      service.validateStatusTransition(BookingStatus.CANCELLED, BookingStatus.ONGOING),
    ).toThrow(BadRequestException);
  });

  it('5. Invalid transition COMPLETED -> ONGOING throws BadRequestException', () => {
    expect(() =>
      service.validateStatusTransition(BookingStatus.COMPLETED, BookingStatus.ONGOING),
    ).toThrow(BadRequestException);
  });
});
