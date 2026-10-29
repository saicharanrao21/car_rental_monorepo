import { Test, TestingModule } from '@nestjs/testing';
import { AdminAuditLogController } from './admin-audit-log.controller';
import { AuditLogService } from './audit-log.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AdminAuditLog Suite', () => {
  let controller: AdminAuditLogController;
  let service: AuditLogService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      auditLog: {
        create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 'log-1', ...data })),
        count: jest.fn().mockResolvedValue(2),
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'log-1',
            adminUserId: 'admin-1',
            action: 'COMMISSION_UPDATE',
            targetType: 'CommissionTier',
            targetId: 'tier-1',
            metadata: { previousRate: 10, newRate: 12 },
            createdAt: new Date(),
            adminUser: { id: 'admin-1', name: 'Super Admin', email: 'admin@drivego.in', role: 'ADMIN' },
          },
        ]),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminAuditLogController],
      providers: [
        AuditLogService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    controller = module.get<AdminAuditLogController>(AdminAuditLogController);
    service = module.get<AuditLogService>(AuditLogService);
  });

  describe('AuditLogService Data Sanitization', () => {
    it('redacts sensitive fields in metadata before persisting to database', async () => {
      const rawMetadata = {
        staffName: 'Rajesh',
        password: 'SuperSecretPassword123!',
        token: 'jwt.access.token.secret',
        nested: {
          refreshToken: 'refresh-token-xyz',
          apiKey: 'pk_live_abcdef123456',
          publicNote: 'Allowed note',
        },
        creditCard: '4111222233334444',
        otp: 1234,
      };

      await service.log('admin-1', 'STAFF_PROVISION', 'Staff', 'staff-1', rawMetadata);

      expect(prisma.auditLog.create).toHaveBeenCalledTimes(1);
      const callData = prisma.auditLog.create.mock.calls[0][0].data;

      expect(callData.adminUserId).toBe('admin-1');
      expect(callData.action).toBe('STAFF_PROVISION');
      expect(callData.metadata.staffName).toBe('Rajesh');
      expect(callData.metadata.password).toBe('[REDACTED]');
      expect(callData.metadata.token).toBe('[REDACTED]');
      expect(callData.metadata.nested.refreshToken).toBe('[REDACTED]');
      expect(callData.metadata.nested.apiKey).toBe('[REDACTED]');
      expect(callData.metadata.nested.publicNote).toBe('Allowed note');
      expect(callData.metadata.creditCard).toBe('[REDACTED]');
      expect(callData.metadata.otp).toBe('[REDACTED]');
    });

    it('gracefully handles empty or null metadata without throwing', async () => {
      await service.log('admin-1', 'VIEW_ACTION', 'User', 'usr-1', null);
      expect(prisma.auditLog.create).toHaveBeenCalled();
    });
  });

  describe('AdminAuditLogController', () => {
    it('returns paginated audit logs with search query parameters', async () => {
      const result = await controller.getAuditLogs({
        page: 1,
        limit: 10,
        action: 'COMMISSION_UPDATE',
      });

      expect(result).toBeDefined();
      expect(result.data).toHaveLength(1);
      expect(result.total).toBe(2);
      expect(result.data[0].action).toBe('COMMISSION_UPDATE');
    });
  });
});

