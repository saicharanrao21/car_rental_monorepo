import { Test, TestingModule } from '@nestjs/testing';
import { KycService } from './kyc.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { KycStatus } from '@prisma/client';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('KycService', () => {
  let service: KycService;

  const mockKycRecord = {
    id: 'kyc-1',
    userId: 'user-1',
    licenceNumber: 'DL1420110012345',
    expiryDate: new Date(Date.now() + 365 * 86400000),
    licenceFrontUrl: 'https://storage.drivego.com/dl_front.jpg',
    licenceBackUrl: 'https://storage.drivego.com/dl_back.jpg',
    status: KycStatus.PENDING,
    rejectionReason: null,
    verifiedAt: null,
  };

  const mockPrismaService = {
    customerKyc: {
      findUnique: jest.fn().mockImplementation(({ where }) => {
        if (where.userId === 'user-1' || where.id === 'kyc-1') {
          return Promise.resolve(mockKycRecord);
        }
        return Promise.resolve(null);
      }),
      findMany: jest.fn().mockResolvedValue([mockKycRecord]),
      create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'kyc-new', ...data, status: KycStatus.PENDING })),
      update: jest.fn().mockImplementation(({ where, data }) => Promise.resolve({ ...mockKycRecord, ...data })),
    },
  };

  const mockAuditLogService = {
    log: jest.fn().mockResolvedValue({}),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        KycService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: AuditLogService, useValue: mockAuditLogService },
      ],
    }).compile();

    service = module.get<KycService>(KycService);
  });

  it('1. Submit KYC creates PENDING record for new user', async () => {
    mockPrismaService.customerKyc.findUnique.mockResolvedValueOnce(null);
    const res = await service.submitKyc('user-new', {
      licenceNumber: 'DL99999',
      expiryDate: new Date(Date.now() + 365 * 86400000).toISOString(),
      licenceFrontUrl: 'front.jpg',
      licenceBackUrl: 'back.jpg',
    });
    expect(res.status).toBe(KycStatus.PENDING);
  });

  it('2. Reject expired licence date during submission', async () => {
    await expect(
      service.submitKyc('user-1', {
        licenceNumber: 'DL99999',
        expiryDate: new Date(Date.now() - 86400000).toISOString(), // Expired yesterday
        licenceFrontUrl: 'front.jpg',
        licenceBackUrl: 'back.jpg',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('3. Admin approve KYC updates status to VERIFIED and logs audit', async () => {
    const res = await service.reviewKyc('admin-1', 'kyc-1', {
      status: KycStatus.VERIFIED,
    });
    expect(res.status).toBe(KycStatus.VERIFIED);
    expect(mockAuditLogService.log).toHaveBeenCalledWith(
      'admin-1',
      'KYC_VERIFIED',
      'CustomerKyc',
      'kyc-1',
      expect.anything(),
    );
  });

  it('4. Admin reject KYC requires rejection reason', async () => {
    await expect(
      service.reviewKyc('admin-1', 'kyc-1', {
        status: KycStatus.REJECTED,
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
