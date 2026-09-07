import { Test, TestingModule } from '@nestjs/testing';
import { DamageClaimsService } from './damage-claims.service';
import { PrismaService } from '../prisma/prisma.service';
import { DepositsService } from '../deposits/deposits.service';
import { UploadsService } from '../uploads/uploads.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { Role, DamageClaimStatus, BookingStatus, Prisma } from '@prisma/client';
import { ClaimDecision } from './dto/adjudicate-claim.dto';
import { ForbiddenException, BadRequestException, ConflictException } from '@nestjs/common';

describe('Phase 5: DamageClaimsService (Post-Trip Damage Claims Workflow & Concurrency)', () => {
  let service: DamageClaimsService;
  let prisma: any;
  let depositsService: any;
  let uploadsService: any;
  let notificationsService: any;
  let auditLogService: any;

  beforeEach(async () => {
    prisma = {
      $transaction: jest.fn().mockImplementation(async (cb) => {
        return cb(prisma);
      }),
      booking: {
        findUnique: jest.fn(),
      },
      damageClaim: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
      },
    };

    depositsService = {
      releaseDeposit: jest.fn().mockResolvedValue({ status: 'REFUNDED' }),
      settleDeduction: jest.fn().mockResolvedValue({ status: 'PARTIALLY_REFUNDED' }),
    };

    uploadsService = {
      getPresignedDownloadUrl: jest.fn().mockImplementation((key) => `https://signed.r2.dev/${key}?token=abc`),
    };

    notificationsService = {
      notifyUser: jest.fn().mockResolvedValue(true),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DamageClaimsService,
        { provide: PrismaService, useValue: prisma },
        { provide: DepositsService, useValue: depositsService },
        { provide: UploadsService, useValue: uploadsService },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<DamageClaimsService>(DamageClaimsService);
  });

  describe('createClaim (SEC-P3-01)', () => {
    it('allows vehicle vendor to submit damage claim on a COMPLETED booking', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b1',
        vendorId: 'v1',
        status: BookingStatus.COMPLETED,
        vendor: { userId: 'vendor_user_1' },
        customer: { id: 'c1' },
      });

      prisma.damageClaim.findFirst.mockResolvedValue(null);

      prisma.damageClaim.create.mockResolvedValue({
        id: 'claim1',
        bookingId: 'b1',
        vendorId: 'v1',
        claimedAmount: new Prisma.Decimal(2500),
        status: DamageClaimStatus.SUBMITTED,
        booking: { customerId: 'c1' },
      });

      const res = await service.createClaim(
        'b1',
        {
          claimedAmount: 2500,
          description: 'Deep dent on passenger side front door',
          damagePhotos: ['inspection-photo/vendor_user_1/dent_1.jpg'],
        },
        { userId: 'vendor_user_1', role: Role.VENDOR },
      );

      expect(res.id).toBe('claim1');
      expect(prisma.damageClaim.create).toHaveBeenCalled();
      expect(notificationsService.notifyUser).toHaveBeenCalled();
    });

    it('rejects concurrent/duplicate active damage claim for the same booking', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b1',
        vendorId: 'v1',
        status: BookingStatus.COMPLETED,
        vendor: { userId: 'vendor_user_1' },
        customer: { id: 'c1' },
      });

      // Existing active claim found in transaction
      prisma.damageClaim.findFirst.mockResolvedValue({
        id: 'claim_existing',
        bookingId: 'b1',
        status: DamageClaimStatus.SUBMITTED,
      });

      await expect(
        service.createClaim(
          'b1',
          {
            claimedAmount: 3000,
            description: 'Duplicate claim attempt',
            damagePhotos: [],
          },
          { userId: 'vendor_user_1', role: Role.VENDOR },
        ),
      ).rejects.toThrow(ConflictException);

      expect(prisma.damageClaim.create).not.toHaveBeenCalled();
    });

    it('rejects claim creation on ongoing or pending bookings', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'b1',
        status: BookingStatus.ONGOING,
        vendor: { userId: 'vendor_user_1' },
        customer: { id: 'c1' },
      });

      await expect(
        service.createClaim(
          'b1',
          {
            claimedAmount: 1500,
            description: 'Scratched side mirror during ongoing rental',
            damagePhotos: [],
          },
          { userId: 'vendor_user_1', role: Role.VENDOR },
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('adjudicateClaim', () => {
    it('approves claim and triggers deposit deduction settlement', async () => {
      prisma.damageClaim.findUnique.mockResolvedValue({
        id: 'claim1',
        bookingId: 'b1',
        claimedAmount: new Prisma.Decimal(3000),
        status: DamageClaimStatus.SUBMITTED,
        booking: { id: 'b1' },
      });

      prisma.damageClaim.update.mockResolvedValue({
        id: 'claim1',
        status: DamageClaimStatus.APPROVED,
        approvedAmount: new Prisma.Decimal(3000),
      });

      const result = await service.adjudicateClaim(
        'claim1',
        {
          decision: ClaimDecision.APPROVED,
          approvedAmount: 3000,
          adminNotes: 'Damage verified via post-trip high-res photos',
        },
        'admin_user_1',
      );

      expect(depositsService.settleDeduction).toHaveBeenCalledWith(
        'b1',
        3000,
        'admin_user_1',
        'Damage verified via post-trip high-res photos',
      );
      expect(result.status).toBe(DamageClaimStatus.APPROVED);
      expect(auditLogService.log).toHaveBeenCalled();
    });

    it('rejects claim and triggers full deposit release back to customer', async () => {
      prisma.damageClaim.findUnique.mockResolvedValue({
        id: 'claim1',
        bookingId: 'b1',
        claimedAmount: new Prisma.Decimal(3000),
        status: DamageClaimStatus.SUBMITTED,
        booking: { id: 'b1' },
      });

      prisma.damageClaim.update.mockResolvedValue({
        id: 'claim1',
        status: DamageClaimStatus.REJECTED,
      });

      const result = await service.adjudicateClaim(
        'claim1',
        {
          decision: ClaimDecision.REJECTED,
          adminNotes: 'Scratch was already present in pre-trip inspection photo',
        },
        'admin_user_1',
      );

      expect(depositsService.releaseDeposit).toHaveBeenCalledWith(
        'b1',
        'admin_user_1',
        expect.stringContaining('Scratch was already present'),
      );
      expect(result.status).toBe(DamageClaimStatus.REJECTED);
    });

    it('successfully adjudicates legacy booking claim without security deposit (BUG-02 fix)', async () => {
      prisma.damageClaim.findUnique.mockResolvedValue({
        id: 'claim_legacy',
        bookingId: 'b_legacy',
        claimedAmount: new Prisma.Decimal(2500),
        status: DamageClaimStatus.UNDER_REVIEW,
        booking: {
          id: 'b_legacy',
          securityDeposit: null,
          protectionDeductible: null,
        },
      });

      depositsService.settleDeduction.mockResolvedValue(null);

      prisma.damageClaim.update.mockResolvedValue({
        id: 'claim_legacy',
        status: DamageClaimStatus.APPROVED,
        approvedAmount: new Prisma.Decimal(2000),
      });

      const result = await service.adjudicateClaim(
        'claim_legacy',
        {
          decision: ClaimDecision.APPROVED,
          approvedAmount: 2000,
          adminNotes: 'Legacy booking settled without deposit deduction',
        },
        'admin_user_1',
      );

      expect(depositsService.settleDeduction).toHaveBeenCalledWith(
        'b_legacy',
        2000,
        'admin_user_1',
        'Legacy booking settled without deposit deduction',
      );
      expect(result.status).toBe(DamageClaimStatus.APPROVED);
      expect(auditLogService.log).toHaveBeenCalledWith(
        'admin_user_1',
        'DAMAGE_CLAIM_APPROVED_NO_DEPOSIT',
        'DamageClaim',
        'claim_legacy',
        expect.objectContaining({
          depositSettled: false,
          actualDepositDeduction: 0,
        }),
      );
    });

    it('rejects duplicate adjudication on already finalized claim', async () => {
      prisma.damageClaim.findUnique.mockResolvedValue({
        id: 'claim_done',
        bookingId: 'b1',
        claimedAmount: new Prisma.Decimal(3000),
        status: DamageClaimStatus.APPROVED,
        booking: { id: 'b1' },
      });

      await expect(
        service.adjudicateClaim(
          'claim_done',
          {
            decision: ClaimDecision.APPROVED,
            approvedAmount: 3000,
            adminNotes: 'Attempting second adjudication',
          },
          'admin_user_1',
        ),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('getAllClaimsForAdmin', () => {
    it('returns paginated list of claims with signed photo URLs', async () => {
      prisma.damageClaim.findMany.mockResolvedValue([
        {
          id: 'claim_1',
          bookingId: 'b1',
          status: DamageClaimStatus.SUBMITTED,
          claimedAmount: new Prisma.Decimal(4000),
          damagePhotos: ['damage/photo1.jpg'],
          booking: {
            customer: { id: 'c1', name: 'John Doe' },
            vendor: { id: 'v1', businessName: 'Prime Rentals' },
            car: { id: 'car1', brand: 'Hyundai', model: 'Creta' },
          },
        },
      ]);
      prisma.damageClaim.count.mockResolvedValue(1);

      const result = await service.getAllClaimsForAdmin('SUBMITTED', 1, 20);

      expect(result.claims).toHaveLength(1);
      expect(result.claims[0].damagePhotos[0]).toContain('https://signed.r2.dev/damage/photo1.jpg');
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
    });
  });
});
