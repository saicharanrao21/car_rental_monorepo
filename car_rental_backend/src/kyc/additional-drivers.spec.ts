import { Test, TestingModule } from '@nestjs/testing';
import { AdditionalDriversService } from './additional-drivers.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import { KycStatus, Role, Prisma } from '@prisma/client';
import { BadRequestException, ForbiddenException } from '@nestjs/common';

describe('AdditionalDriversService (Phase 4 Feature 29)', () => {
  let service: AdditionalDriversService;
  let prisma: any;
  let notificationsService: any;
  let auditLogService: any;

  beforeEach(async () => {
    prisma = {
      booking: {
        findUnique: jest.fn(),
      },
      customerKyc: {
        findFirst: jest.fn(),
      },
      additionalDriver: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
    };

    notificationsService = {
      createNotification: jest.fn().mockResolvedValue(true),
      notifyUser: jest.fn().mockResolvedValue({ id: 'notif_1' }),
    };

    auditLogService = {
      log: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdditionalDriversService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notificationsService },
        { provide: AuditLogService, useValue: auditLogService },
      ],
    }).compile();

    service = module.get<AdditionalDriversService>(AdditionalDriversService);
  });

  describe('addDriver', () => {
    it('creates an additional driver record with PENDING status for new licence', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'cust_1',
        additionalDrivers: [],
      });

      prisma.customerKyc.findFirst.mockResolvedValue(null);
      prisma.additionalDriver.create.mockImplementation((args: any) =>
        Promise.resolve({ id: 'driver_1', ...args.data }),
      );

      const res = await service.addDriver(
        'book_1',
        {
          fullName: 'Alice Smith',
          phone: '+919876543211',
          licenceNumber: 'MH0220201234567',
          licenceFrontUrl: 'https://cdn.drivego.in/kyc/front.jpg',
          licenceBackUrl: 'https://cdn.drivego.in/kyc/back.jpg',
          expiryDate: '2030-01-01',
        },
        { userId: 'cust_1', role: Role.CUSTOMER },
      );

      expect(res.id).toBe('driver_1');
      expect(res.fullName).toBe('Alice Smith');
      expect(res.kycStatus).toBe(KycStatus.PENDING);
      expect(res.feeAmount).toEqual(new Prisma.Decimal(350));
    });

    it('auto-verifies if licence is already verified in customer KYC registry', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'cust_1',
        additionalDrivers: [],
      });

      prisma.customerKyc.findFirst.mockResolvedValue({
        id: 'kyc_verified_1',
        licenceNumber: 'MH0220201234567',
        status: KycStatus.VERIFIED,
      });

      prisma.additionalDriver.create.mockImplementation((args: any) =>
        Promise.resolve({ id: 'driver_2', ...args.data }),
      );

      const res = await service.addDriver(
        'book_1',
        {
          fullName: 'Alice Smith',
          phone: '+919876543211',
          licenceNumber: 'MH0220201234567',
          licenceFrontUrl: 'https://cdn.drivego.in/kyc/front.jpg',
          licenceBackUrl: 'https://cdn.drivego.in/kyc/back.jpg',
          expiryDate: '2030-01-01',
        },
        { userId: 'cust_1', role: Role.CUSTOMER },
      );

      expect(res.kycStatus).toBe(KycStatus.VERIFIED);
    });

    it('rejects adding more than 2 additional drivers per booking', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'cust_1',
        additionalDrivers: [{ id: 'd1' }, { id: 'd2' }],
      });

      await expect(
        service.addDriver(
          'book_1',
          {
            fullName: 'Third Driver',
            phone: '+919876543212',
            licenceNumber: 'MH0220209999999',
            licenceFrontUrl: 'https://cdn.drivego.in/kyc/f.jpg',
            licenceBackUrl: 'https://cdn.drivego.in/kyc/b.jpg',
            expiryDate: '2030-01-01',
          },
          { userId: 'cust_1', role: Role.CUSTOMER },
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('verifyDriver (Admin adjudication)', () => {
    it('approves driver licence and notifies customer', async () => {
      prisma.additionalDriver.findUnique.mockResolvedValue({
        id: 'driver_1',
        bookingId: 'book_1',
        fullName: 'Bob Smith',
        booking: { customerId: 'cust_1' },
      });

      prisma.additionalDriver.update.mockResolvedValue({
        id: 'driver_1',
        kycStatus: KycStatus.VERIFIED,
      });

      const res = await service.verifyDriver('driver_1', true, undefined, 'admin_1');

      expect(res.kycStatus).toBe(KycStatus.VERIFIED);
      expect(auditLogService.log).toHaveBeenCalled();
      expect(notificationsService.notifyUser).toHaveBeenCalled();
    });
  });
});
