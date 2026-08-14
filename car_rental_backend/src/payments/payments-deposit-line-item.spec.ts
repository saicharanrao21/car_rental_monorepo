import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingStatus, PaymentStatus, SecurityDepositStatus } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { BadRequestException, ConflictException } from '@nestjs/common';

describe('Phase 5 Hardening: Payments & Deposit Line-Item Integrity (SEC-P2-03)', () => {
  let service: PaymentsService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      securityDeposit: {
        update: jest.fn(),
      },
      $transaction: jest.fn().mockImplementation(async (cb) => {
        return cb(prisma);
      }),
    };

    const configService = new ConfigService({
      NODE_ENV: 'test',
      RAZORPAY_USE_MOCK: 'true',
      RAZORPAY_KEY_ID: 'rzp_test_key_123',
      RAZORPAY_KEY_SECRET: 'rzp_test_secret_456',
    });

    const notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: configService },
        { provide: NotificationsService, useValue: notificationsService },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
  });

  describe('createOrder with Server-Authoritative Fare + Deposit Line-Item', () => {
    it('correctly calculates total amount combining trip fare and security deposit', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_dep_1',
        customerId: 'cust_1',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(10000), // Rs 10,000
        securityDeposit: {
          id: 'dep_1',
          amount: new Decimal(5000), // Rs 5,000
        },
      });

      prisma.payment.findUnique.mockResolvedValue(null);
      prisma.payment.create.mockResolvedValue({ id: 'pay_1' });

      const res = await service.createOrder('book_dep_1', 'cust_1');

      expect(res.amount).toBe(1500000); // 15,000 * 100 paise
      expect(res.breakdown).toEqual({
        tripFare: 10000,
        securityDeposit: 5000,
        totalAmount: 15000,
      });
      expect(prisma.payment.create).toHaveBeenCalledWith({
        data: {
          bookingId: 'book_dep_1',
          razorpayOrderId: expect.stringContaining('order_mock_'),
          amount: new Decimal(15000),
          status: PaymentStatus.CREATED,
        },
      });
    });

    it('correctly handles bookings without security deposit (deposit = 0)', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_nodep_1',
        customerId: 'cust_1',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(8000),
        securityDeposit: null,
      });

      prisma.payment.findUnique.mockResolvedValue(null);
      prisma.payment.create.mockResolvedValue({ id: 'pay_2' });

      const res = await service.createOrder('book_nodep_1', 'cust_1');

      expect(res.amount).toBe(800000); // 8,000 * 100 paise
      expect(res.breakdown).toEqual({
        tripFare: 8000,
        securityDeposit: 0,
        totalAmount: 8000,
      });
    });

    it('rejects duplicate order creation if payment is already PAID', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_paid_1',
        customerId: 'cust_1',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(5000),
      });

      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_paid',
        status: PaymentStatus.PAID,
      });

      await expect(
        service.createOrder('book_paid_1', 'cust_1'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('verifyPayment with Deposit Activation', () => {
    it('verifies payment and atomically marks security deposit as HELD', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_dep_1',
        customerId: 'cust_1',
        status: BookingStatus.PENDING,
        totalFare: new Decimal(10000),
        securityDeposit: {
          id: 'dep_1',
          amount: new Decimal(5000),
        },
      });

      prisma.payment.findUnique.mockResolvedValue({
        id: 'pay_1',
        bookingId: 'book_dep_1',
        razorpayOrderId: 'order_mock_123',
        amount: new Decimal(15000),
        status: PaymentStatus.CREATED,
      });

      prisma.payment.update.mockResolvedValue({
        id: 'pay_1',
        status: PaymentStatus.PAID,
      });

      prisma.booking.update.mockResolvedValue({
        id: 'book_dep_1',
        customerId: 'cust_1',
        status: BookingStatus.CONFIRMED,
      });

      const res = await service.verifyPayment(
        {
          bookingId: 'book_dep_1',
          razorpayOrderId: 'order_mock_123',
          razorpayPaymentId: 'pay_rzp_abc',
          razorpaySignature: 'mock_signature',
        },
        'cust_1',
      );

      expect(res.success).toBe(true);
      expect(prisma.securityDeposit.update).toHaveBeenCalledWith({
        where: { id: 'dep_1' },
        data: expect.objectContaining({
          status: SecurityDepositStatus.HELD,
          razorpayPaymentId: 'pay_rzp_abc',
        }),
      });
      expect(prisma.booking.update).toHaveBeenCalledWith({
        where: { id: 'book_dep_1' },
        data: { status: BookingStatus.CONFIRMED },
      });
    });
  });
});
