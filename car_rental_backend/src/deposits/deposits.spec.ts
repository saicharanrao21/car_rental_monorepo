import { Test, TestingModule } from '@nestjs/testing';
import { DepositsService } from './deposits.service';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { Role, SecurityDepositStatus, Prisma, BookingStatus } from '@prisma/client';
import {
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { CollateralType } from './dto/record-collateral.dto';

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

    it('returns null safely when settling deduction for a booking without a deposit', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue(null);

      const result = await service.settleDeduction('b_nodep', 2000, 'admin_1', 'No deposit test');

      expect(result).toBeNull();
      expect(paymentsService.refund).not.toHaveBeenCalled();
    });

    it('caps deduction to deposit amount when damage exceeds deposit, forfeiting full deposit with zero refund', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep1',
        bookingId: 'b1',
        amount: new Prisma.Decimal(3000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 1 });
      prisma.securityDeposit.update.mockResolvedValue({
        id: 'dep1',
        status: SecurityDepositStatus.FORFEITED,
        deductedAmount: new Prisma.Decimal(3000),
        refundedAmount: new Prisma.Decimal(0),
      });

      const result = await service.settleDeduction('b1', 5000, 'admin_1', 'High damage');

      // Deduction capped to 3000, remaining refund is 0, so Razorpay refund is NOT called
      expect(prisma.securityDeposit.updateMany).toHaveBeenCalledWith({
        where: { id: 'dep1', status: SecurityDepositStatus.HELD },
        data: expect.objectContaining({
          status: SecurityDepositStatus.FORFEITED,
          deductedAmount: new Prisma.Decimal(3000),
        }),
      });
      expect(paymentsService.refund).not.toHaveBeenCalled();
      expect(result.status).toBe(SecurityDepositStatus.FORFEITED);
    });
  });

  describe('Customer Collateral Lifecycle & Vendor Handover', () => {
    it('successfully releases physical collateral without making gateway refund call', async () => {
      prisma.securityDeposit.findUnique.mockResolvedValue({
        id: 'dep_col_1',
        bookingId: 'b_col',
        amount: new Prisma.Decimal(5000),
        deductedAmount: new Prisma.Decimal(0),
        status: SecurityDepositStatus.HELD,
        razorpayPaymentId: 'COLLATERAL:PHYSICAL_VEHICLE:KA-05-MH-1234',
        booking: { customerId: 'c1' },
      });

      prisma.securityDeposit.updateMany.mockResolvedValue({ count: 1 });
      prisma.securityDeposit.update.mockResolvedValue({
        id: 'dep_col_1',
        status: SecurityDepositStatus.REFUNDED,
        refundedAmount: new Prisma.Decimal(5000),
      });

      const res = await service.releaseDeposit('b_col', 'admin_1', 'Collateral released to customer');

      expect(paymentsService.refund).not.toHaveBeenCalled();
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'c1',
        'Collateral Returned',
        expect.stringContaining('physical collateral for booking b_col has been returned'),
      );
      expect(res.status).toBe(SecurityDepositStatus.REFUNDED);
    });

    it('records physical vehicle collateral at yard during handover', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b100',
        customerId: 'c100',
        status: BookingStatus.HANDOVER_READY,
        vendor: { userId: 'v_user_1', businessName: 'Bangalore Fleet Hub' },
        securityDeposit: { amount: new Prisma.Decimal(5000) },
      });

      prisma.securityDeposit.upsert.mockResolvedValue({
        id: 'dep_100',
        bookingId: 'b100',
        status: SecurityDepositStatus.HELD,
        razorpayPaymentId: 'COLLATERAL:PHYSICAL_VEHICLE:KA-01-AB-1234',
      });

      const res = await service.recordCollateral(
        'b100',
        {
          collateralType: CollateralType.PHYSICAL_VEHICLE,
          vehicleRegistrationNumber: 'KA-01-AB-1234',
          vehicleMake: 'Honda',
          vehicleModel: 'Activa 6G',
          yardSlotNumber: 'BAY-12',
          keysCollected: true,
        },
        { userId: 'v_user_1', role: Role.VENDOR },
      );

      expect(res.success).toBe(true);
      expect(res.collateral.type).toBe(CollateralType.PHYSICAL_VEHICLE);
      expect(auditLogService.log).toHaveBeenCalledWith(
        'v_user_1',
        'CUSTOMER_COLLATERAL_RECORDED',
        'SecurityDeposit',
        'dep_100',
        expect.anything(),
      );
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'c100',
        'Collateral Verified & Secured',
        expect.stringContaining('Secondary vehicle (KA-01-AB-1234) safely parked'),
      );
    });

    it('records original document collateral safely in yard safe vault', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b101',
        customerId: 'c101',
        status: BookingStatus.CONFIRMED,
        vendor: { userId: 'v_user_2', businessName: 'Metro Rentals' },
        securityDeposit: null,
      });

      prisma.securityDeposit.upsert.mockResolvedValue({
        id: 'dep_101',
        bookingId: 'b101',
        status: SecurityDepositStatus.HELD,
        razorpayPaymentId: 'COLLATERAL:ORIGINAL_DOCUMENT:PASSPORT_Z1234567',
      });

      const res = await service.recordCollateral(
        'b101',
        {
          collateralType: CollateralType.ORIGINAL_DOCUMENT,
          documentType: 'PASSPORT',
          documentNumberMasked: 'Z1234567',
          vaultLockerNumber: 'SAFE-04',
          verifiedPhysically: true,
        },
        { userId: 'v_user_2', role: Role.VENDOR },
      );

      expect(res.success).toBe(true);
      expect(res.collateral.type).toBe(CollateralType.ORIGINAL_DOCUMENT);
      expect(notificationsService.notifyUser).toHaveBeenCalledWith(
        'c101',
        'Collateral Verified & Secured',
        expect.stringContaining('Original PASSPORT secured in vendor vault locker SAFE-04'),
      );
    });

    it('rejects vehicle collateral if keys are not collected', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b102',
        customerId: 'c102',
        status: BookingStatus.CONFIRMED,
        vendor: { userId: 'v_user_3', businessName: 'Apex Cars' },
      });

      await expect(
        service.recordCollateral(
          'b102',
          {
            collateralType: CollateralType.PHYSICAL_VEHICLE,
            vehicleRegistrationNumber: 'KA-02-CD-5678',
            keysCollected: false,
          },
          { userId: 'v_user_3', role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('retrieves collateral details for a booking', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b103',
        customerId: 'c103',
        vendor: { userId: 'v_user_4' },
        securityDeposit: {
          id: 'dep_103',
          bookingId: 'b103',
          amount: new Prisma.Decimal(5000),
          status: SecurityDepositStatus.HELD,
          heldAt: new Date('2026-10-30T10:00:00Z'),
          razorpayPaymentId: 'COLLATERAL:PHYSICAL_VEHICLE:KA-03-EF-9999',
        },
      });

      const res = await service.getCollateral('b103', {
        userId: 'c103',
        role: Role.CUSTOMER,
      });

      expect(res.hasCollateral).toBe(true);
      expect(res.collateralType).toBe('PHYSICAL_VEHICLE');
      expect(res.collateralIdentifier).toBe('KA-03-EF-9999');
      expect(res.status).toBe(SecurityDepositStatus.HELD);
    });
  });
});
