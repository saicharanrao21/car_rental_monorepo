import { Test, TestingModule } from '@nestjs/testing';
import { DepositsService } from './deposits.service';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { Role, SecurityDepositStatus, Prisma } from '@prisma/client';
import {
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';

describe('Phase 5: DepositsService (Security Deposit Lifecycle & Concurrency)', () => {
  let service: DepositsService;
  let prisma: any;
  let paymentsService: any;
  let notificationsService: any;
  let auditLogService: any;

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
      },
      securityDeposit: {
        findUnique: jest.fn(),
        upsert: jest.fn().mockResolvedValue({}),
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };

    paymentsService = {
      refund: jest.fn().mockResolvedValue({ refundId: 'rfnd_dep_123', refundAmount: new Prisma.Decimal(5000), refundStatus: 'PROCESSED' }),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DepositsService,
        { provide: PrismaService, useValue: prisma },
        { provide: PaymentsService, useValue: paymentsService },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<DepositsService>(DepositsService);
  });

  describe('getDeposit', () => {
    it('allows customer to view their own security deposit', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b1',
        customerId: 'c1',
        vendor: { userId: 'v1_user' },
        securityDeposit: {
          id: 'dep1',
          bookingId: 'b1',
          amount: new Prisma.Decimal(5000),
          status: SecurityDepositStatus.HELD,
        },
      });

      const res = await service.getDeposit('b1', { userId: 'c1', role: Role.CUSTOMER });
      expect(res.id).toBe('dep1');
      expect(res.amount.toNumber()).toBe(5000);
    });

    it('rejects cross-customer deposit lookup (Anti-IDOR)', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b1',
        customerId: 'c1',
        vendor: { userId: 'v1_user' },
        securityDeposit: { id: 'dep1' },
      });

      await expect(
        service.getDeposit('b1', { userId: 'c2_attacker', role: Role.CUSTOMER }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('releaseDeposit Concurrency & Idempotency (SEC-P2-01)', () => {
    it('successfully refunds full security deposit when no damages were deducted', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 1 });
      prisma.securityDeposit.update.mockResolvedValue({
        id: 'dep1',
        status: SecurityDepositStatus.REFUNDED,
        refundedAmount: new Prisma.Decimal(5000),
      });

      const result = await service.releaseDeposit('b1', 'admin_1', 'Clean return');

      expect(paymentsService.refund).toHaveBeenCalledWith(
        'b1',
        500000, // 5000 * 100 paise
        'Clean return',
        'SECURITY_DEPOSIT_RELEASE',
      );
      expect(prisma.securityDeposit.updateMany).toHaveBeenCalledWith({
        where: { id: 'dep1', status: SecurityDepositStatus.HELD },
        data: expect.objectContaining({ status: SecurityDepositStatus.REFUNDED }),
      });
      expect(auditLogService.log).toHaveBeenCalled();
      expect(result.status).toBe(SecurityDepositStatus.REFUNDED);
    });

    it('rejects concurrent second release request when compare-and-swap update returns count 0', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      // Simulate race: another request already updated status from HELD -> REFUNDED
      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 0 });

      await expect(service.releaseDeposit('b1', 'admin_2')).rejects.toThrow(
        ConflictException,
      );

      // Crucial: Razorpay refund MUST NEVER be called if the atomic lock wasn't acquired
      expect(paymentsService.refund).not.toHaveBeenCalled();
    });

    it('reverts deposit status to HELD when gateway refund fails, allowing subsequent retry', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 1 });
      paymentsService.refund.mockRejectedValue(new Error('Gateway timeout'));

      let caughtError: any;
      try {
        await service.releaseDeposit('b1', 'admin_1');
      } catch (err) {
        caughtError = err;
      }

      expect(caughtError).toBeInstanceOf(BadRequestException);
      expect(caughtError.message).toContain('Payment gateway refund failed');

      // Verify status was reverted back to HELD
      expect(prisma.securityDeposit.update).toHaveBeenCalledWith({
        where: { id: 'dep1' },
        data: { status: SecurityDepositStatus.HELD, releasedAt: null },
      });
    });

    it('rejects release if deposit is not in HELD status', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.REFUNDED,
        booking: { customerId: 'c1' },
      });

      await expect(service.releaseDeposit('b1')).rejects.toThrow(ConflictException);
      expect(paymentsService.refund).not.toHaveBeenCalled();
    });
  });

  describe('settleDeduction Concurrency (SEC-P2-01)', () => {
    it('deducts approved damage amount and refunds remaining balance', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 1 });
      prisma.securityDeposit.update.mockResolvedValue({
        id: 'dep1',
        status: SecurityDepositStatus.PARTIALLY_REFUNDED,
        deductedAmount: new Prisma.Decimal(2000),
        refundedAmount: new Prisma.Decimal(3000),
      });

      const result = await service.settleDeduction('b1', 2000, 'admin_1', 'Bumper scratch repaired');

      expect(paymentsService.refund).toHaveBeenCalledWith(
        'b1',
        300000, // 3000 * 100 paise
        expect.stringContaining('Partial deposit release'),
        'DAMAGE_CLAIM_SETTLEMENT_REMAINDER',
      );
      expect(result.status).toBe(SecurityDepositStatus.PARTIALLY_REFUNDED);
    });

    it('rejects concurrent second deduction attempt with ConflictException', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 0 });

      await expect(
        service.settleDeduction('b1', 2000, 'admin_2', 'Duplicate call'),
      ).rejects.toThrow(ConflictException);

      expect(paymentsService.refund).not.toHaveBeenCalled();
    });
  });
});
