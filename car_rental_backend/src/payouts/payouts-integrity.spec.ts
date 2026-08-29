import { Test, TestingModule } from '@nestjs/testing';
import { PayoutsService } from './payouts.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { PayoutStatus, PaymentStatus, Prisma } from '@prisma/client';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('Phase 4D: Payouts Integrity & Balance Reservation Security', () => {
  let service: PayoutsService;
  let prisma: any;
  let auditLogService: any;
  let notificationsService: any;

  const mockVendor = {
    id: 'vendor-1',
    businessName: 'Apex Car Rentals',
    ownerName: 'Rahul Sharma',
    userId: 'user-vendor-1',
  };

  beforeEach(async () => {
    prisma = {
      vendor: {
        findUnique: jest.fn().mockResolvedValue(mockVendor),
      },
      booking: {
        findMany: jest.fn(),
      },
      payout: {
        findMany: jest.fn(),
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
      },
      $queryRaw: jest.fn().mockResolvedValue([{ id: 'vendor-1' }]),
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(prisma);
      }),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue({ id: 'audit-1' }),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue({}),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PayoutsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<PayoutsService>(PayoutsService);
  });

  describe('Vendor Earnings Summary & Balance Reservation', () => {
    it('1. should calculate available balance deducting both PAID and PENDING payouts', async () => {
      // Completed bookings with verified payment = ₹10,000 total netToVendor
      prisma.booking.findMany.mockResolvedValue([
        { id: 'b1', netToVendor: new Prisma.Decimal(6000), createdAt: new Date() },
        { id: 'b2', netToVendor: new Prisma.Decimal(4000), createdAt: new Date() },
      ]);

      // Paid payouts = ₹3,000
      prisma.payout.findMany
        .mockResolvedValueOnce([{ id: 'p1', amount: new Prisma.Decimal(3000), status: PayoutStatus.PAID }])
        // Pending payouts = ₹2,000
        .mockResolvedValueOnce([{ id: 'p2', amount: new Prisma.Decimal(2000), status: PayoutStatus.PENDING }]);

      const summary = await service.getVendorEarningsSummary('vendor-1');

      expect(summary.totalEarnings).toBe(10000);
      expect(summary.totalPaid).toBe(3000);
      expect(summary.totalPending).toBe(2000);
      expect(summary.availableBalance).toBe(5000); // 10000 - 3000 - 2000
      expect(summary.outstandingBalance).toBe(7000); // 10000 - 3000
    });

    it('2. should enforce paid-only earnings and ignore completed bookings without PAID payment', async () => {
      prisma.booking.findMany.mockResolvedValue([
        { id: 'b1', netToVendor: new Prisma.Decimal(5000), createdAt: new Date() },
      ]);
      prisma.payout.findMany
        .mockResolvedValueOnce([]) // No paid payouts
        .mockResolvedValueOnce([]); // No pending payouts

      await service.getVendorEarningsSummary('vendor-1');

      expect(prisma.booking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            vendorId: 'vendor-1',
            status: 'COMPLETED',
            payment: { status: PaymentStatus.PAID },
          },
        }),
      );
    });
  });

  describe('createPayout Concurrency & Transactional Validation', () => {
    it('3. should reject non-positive payout amounts', async () => {
      await expect(service.createPayout('vendor-1', 0)).rejects.toThrow(BadRequestException);
      await expect(service.createPayout('vendor-1', -500)).rejects.toThrow(BadRequestException);
    });

    it('4. should reject payout when requested amount exceeds available balance due to PENDING payouts', async () => {
      // Total earnings = ₹10,000
      prisma.booking.findMany.mockResolvedValue([
        { id: 'b1', netToVendor: new Prisma.Decimal(10000), createdAt: new Date() },
      ]);
      // Paid = ₹2,000
      // Pending = ₹6,000 -> Available = ₹2,000
      prisma.payout.findMany
        .mockResolvedValueOnce([{ id: 'p1', amount: new Prisma.Decimal(2000), status: PayoutStatus.PAID }])
        .mockResolvedValueOnce([{ id: 'p2', amount: new Prisma.Decimal(6000), status: PayoutStatus.PENDING }]);

      // Attempt to request ₹3,000 when only ₹2,000 is available
      await expect(service.createPayout('vendor-1', 3000)).rejects.toThrow(BadRequestException);
      expect(prisma.payout.create).not.toHaveBeenCalled();
    });

    it('5. should execute createPayout inside transaction with FOR UPDATE row lock and create PENDING payout', async () => {
      prisma.booking.findMany.mockResolvedValue([
        { id: 'b1', netToVendor: new Prisma.Decimal(10000), createdAt: new Date() },
      ]);
      prisma.payout.findMany
        .mockResolvedValueOnce([{ id: 'p1', amount: new Prisma.Decimal(2000), status: PayoutStatus.PAID }])
        .mockResolvedValueOnce([{ id: 'p2', amount: new Prisma.Decimal(3000), status: PayoutStatus.PENDING }]);

      const createdPayoutMock = {
        id: 'payout-new-1',
        vendorId: 'vendor-1',
        amount: new Prisma.Decimal(4000),
        status: PayoutStatus.PENDING,
      };
      prisma.payout.create.mockResolvedValue(createdPayoutMock);

      // Available is ₹5,000. Requesting ₹4,000.
      const result = await service.createPayout('vendor-1', 4000, 'admin-user-1');

      expect(prisma.$transaction).toHaveBeenCalled();
      expect(prisma.$queryRaw).toHaveBeenCalled();
      expect(prisma.payout.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            vendorId: 'vendor-1',
            amount: new Prisma.Decimal(4000),
            status: PayoutStatus.PENDING,
          }),
        }),
      );
      expect(auditLogService.log).toHaveBeenCalledWith(
        'admin-user-1',
        'PAYOUT_CREATED',
        'Payout',
        'payout-new-1',
        expect.objectContaining({
          vendorId: 'vendor-1',
          amount: 4000,
        }),
      );
      expect(result).toEqual(createdPayoutMock);
    });
  });

  describe('markPayoutPaid Lifecycle & Daily Earnings', () => {
    it('6. should transition payout to PAID, timestamp paidAt, and notify vendor', async () => {
      prisma.payout.findUnique.mockResolvedValue({
        id: 'payout-1',
        amount: new Prisma.Decimal(5000),
        status: PayoutStatus.PENDING,
      });

      const updatedMock = {
        id: 'payout-1',
        amount: new Prisma.Decimal(5000),
        status: PayoutStatus.PAID,
        paidAt: new Date(),
        vendor: mockVendor,
      };
      prisma.payout.update.mockResolvedValue(updatedMock);

      const result = await service.markPayoutPaid('payout-1', 'UTR Bank Ref #998877');

      expect(result.status).toBe(PayoutStatus.PAID);
      expect(prisma.payout.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'payout-1' },
          data: expect.objectContaining({
            status: PayoutStatus.PAID,
          }),
        }),
      );
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'user-vendor-1',
        'Payout Marked Paid',
        expect.stringContaining('5000'),
      );
    });

    it('7. should reject markPayoutPaid if payout is already PAID', async () => {
      prisma.payout.findUnique.mockResolvedValue({
        id: 'payout-1',
        status: PayoutStatus.PAID,
      });

      await expect(service.markPayoutPaid('payout-1')).rejects.toThrow(BadRequestException);
      expect(prisma.payout.update).not.toHaveBeenCalled();
    });

    it('8. should filter paid-only completed bookings in getDailyEarnings', async () => {
      prisma.booking.findMany.mockResolvedValue([
        {
          id: 'b1',
          netToVendor: new Prisma.Decimal(2500),
          createdAt: new Date(),
        },
      ]);

      const daily = await service.getDailyEarnings('vendor-1', 7);

      expect(prisma.booking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            vendorId: 'vendor-1',
            status: 'COMPLETED',
            payment: { status: PaymentStatus.PAID },
          }),
        }),
      );
      expect(Array.isArray(daily)).toBe(true);
    });
  });
});
