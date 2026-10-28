import { Test, TestingModule } from '@nestjs/testing';
import { AdminStaffService } from './admin-staff.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from './audit-log.service';
import { Role } from '@prisma/client';
import { StaffRole, AdminPermission, getPermissionsForUser } from '../auth/permissions.enum';
import { ConflictException, BadRequestException, NotFoundException } from '@nestjs/common';

describe('AdminStaffService & Granular RBAC Delegation', () => {
  let service: AdminStaffService;
  let prisma: any;
  let auditLog: any;

  const mockUsers: any[] = [];
  const mockTokens: any[] = [];

  beforeEach(async () => {
    mockUsers.length = 0;
    mockTokens.length = 0;

    prisma = {
      user: {
        findMany: jest.fn().mockImplementation(({ where }) => {
          return mockUsers.filter((u) => {
            if (where.role?.in && !where.role.in.includes(u.role)) return false;
            if (where.staffRole && u.staffRole !== where.staffRole) return false;
            return true;
          });
        }),
        count: jest.fn().mockImplementation(() => mockUsers.length),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id) return mockUsers.find((u) => u.id === where.id) || null;
          if (where.phone) return mockUsers.find((u) => u.phone === where.phone) || null;
          return null;
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          if (where.email) return mockUsers.find((u) => u.email === where.email) || null;
          if (where.id) return mockUsers.find((u) => u.id === where.id) || null;
          return null;
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const user = {
            id: `usr_${Date.now()}_${Math.random().toString(36).substring(7)}`,
            ...data,
            banned: false,
            createdAt: new Date(),
            updatedAt: new Date(),
            _count: { refreshTokens: 0 },
          };
          mockUsers.push(user);
          return user;
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const idx = mockUsers.findIndex((u) => u.id === where.id);
          if (idx === -1) throw new NotFoundException();
          mockUsers[idx] = { ...mockUsers[idx], ...data, updatedAt: new Date() };
          return mockUsers[idx];
        }),
      },
      refreshToken: {
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          let count = 0;
          for (const t of mockTokens) {
            if (t.userId === where.userId && (where.revoked === undefined || t.revoked === where.revoked)) {
              t.revoked = data.revoked;
              count++;
            }
          }
          return { count };
        }),
      },
    };

    auditLog = {
      log: jest.fn().mockResolvedValue({ id: 'audit_1' }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminStaffService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: auditLog },
      ],
    }).compile();

    service = module.get<AdminStaffService>(AdminStaffService);
  });

  describe('Staff Provisioning & Role Mapping', () => {
    it('1. should successfully provision an Operations Manager with base Role.ADMIN', async () => {
      const dto = {
        name: 'Arjun Ops',
        email: 'arjun.ops@drivego.in',
        phone: '9876500001',
        staffRole: StaffRole.OPERATIONS_MANAGER,
        password: 'SecurePassword123!',
      };

      const staff = await service.createStaff(dto, 'admin_super');
      expect(staff.name).toBe('Arjun Ops');
      expect(staff.staffRole).toBe(StaffRole.OPERATIONS_MANAGER);
      expect(staff.role).toBe(Role.ADMIN);
      expect(auditLog.log).toHaveBeenCalledWith(
        'admin_super',
        'STAFF_ACCOUNT_PROVISIONED',
        'User',
        staff.id,
        expect.objectContaining({ staffRole: StaffRole.OPERATIONS_MANAGER }),
      );
    });

    it('2. should provision a Customer Support agent with base Role.SUPPORT_AGENT', async () => {
      const dto = {
        name: 'Sneha Support',
        email: 'sneha.support@drivego.in',
        phone: '9876500002',
        staffRole: StaffRole.CUSTOMER_SUPPORT,
        password: 'SecurePassword123!',
      };

      const staff = await service.createStaff(dto, 'admin_super');
      expect(staff.staffRole).toBe(StaffRole.CUSTOMER_SUPPORT);
      expect(staff.role).toBe(Role.SUPPORT_AGENT);
    });

    it('3. should reject provisioning if phone number already exists', async () => {
      mockUsers.push({ id: 'u1', phone: '9876500003', email: 'existing@drivego.in' });
      const dto = {
        name: 'Duplicate Phone',
        email: 'new@drivego.in',
        phone: '9876500003',
        staffRole: StaffRole.FINANCE_MANAGER,
        password: 'Password123!',
      };

      await expect(service.createStaff(dto, 'admin_super')).rejects.toThrow(ConflictException);
    });

    it('4. should reject provisioning if email already exists', async () => {
      mockUsers.push({ id: 'u2', phone: '9876500004', email: 'duplicate@drivego.in' });
      const dto = {
        name: 'Duplicate Email',
        email: 'duplicate@drivego.in',
        phone: '9876500005',
        staffRole: StaffRole.MARKETING_MANAGER,
        password: 'Password123!',
      };

      await expect(service.createStaff(dto, 'admin_super')).rejects.toThrow(ConflictException);
    });
  });

  describe('Staff Account Lifecycle & Security Assertions', () => {
    it('5. should prevent an administrator from suspending their own account (Self-Ban Defense)', async () => {
      mockUsers.push({
        id: 'admin_super',
        name: 'Super Admin',
        email: 'super@drivego.in',
        role: Role.ADMIN,
        staffRole: StaffRole.SUPER_ADMIN,
        banned: false,
      });

      await expect(
        service.updateStaff('admin_super', { banned: true }, 'admin_super'),
      ).rejects.toThrow(BadRequestException);
    });

    it('6. should allow delegating role changes and update base role accordingly', async () => {
      const targetUser = {
        id: 'staff_target',
        name: 'Promoted Agent',
        email: 'promoted@drivego.in',
        role: Role.SUPPORT_AGENT,
        staffRole: StaffRole.CUSTOMER_SUPPORT,
        banned: false,
      };
      mockUsers.push(targetUser);

      const updated = await service.updateStaff(
        'staff_target',
        { staffRole: StaffRole.OPERATIONS_MANAGER },
        'admin_super',
      );

      expect(updated.staffRole).toBe(StaffRole.OPERATIONS_MANAGER);
      expect(updated.role).toBe(Role.ADMIN);
      expect(auditLog.log).toHaveBeenCalledWith(
        'admin_super',
        'STAFF_ACCOUNT_UPDATED',
        'User',
        'staff_target',
        expect.objectContaining({ staffRole: StaffRole.OPERATIONS_MANAGER }),
      );
    });

    it('7. should revoke all active sessions for a compromised staff user', async () => {
      mockUsers.push({ id: 'staff_compromised', name: 'Compromised User' });
      mockTokens.push(
        { id: 't1', userId: 'staff_compromised', revoked: false },
        { id: 't2', userId: 'staff_compromised', revoked: false },
        { id: 't3', userId: 'other_user', revoked: false },
      );

      const result = await service.revokeSessions('staff_compromised', 'admin_super');
      expect(result.success).toBe(true);
      expect(result.revokedCount).toBe(2);
      expect(mockTokens[0].revoked).toBe(true);
      expect(mockTokens[1].revoked).toBe(true);
      expect(mockTokens[2].revoked).toBe(false);
      expect(auditLog.log).toHaveBeenCalledWith(
        'admin_super',
        'STAFF_SESSIONS_REVOKED',
        'User',
        'staff_compromised',
        expect.objectContaining({ revokedSessionCount: 2 }),
      );
    });
  });

  describe('Granular RBAC Permission Matrix Evaluation', () => {
    it('8. should grant full permissions to SUPER_ADMIN', () => {
      const perms = getPermissionsForUser(Role.ADMIN, StaffRole.SUPER_ADMIN);
      expect(perms).toContain(AdminPermission.SYSTEM_CONFIG_WRITE);
      expect(perms).toContain(AdminPermission.PAYOUT_EXECUTE);
      expect(perms).toContain(AdminPermission.FLEET_WRITE);
    });

    it('9. should grant finance permissions but deny system config write to FINANCE_MANAGER', () => {
      const perms = getPermissionsForUser(Role.ADMIN, StaffRole.FINANCE_MANAGER);
      expect(perms).toContain(AdminPermission.PAYOUT_APPROVE);
      expect(perms).toContain(AdminPermission.PAYOUT_EXECUTE);
      expect(perms).toContain(AdminPermission.REFUND_ADJUDICATE);
      expect(perms).not.toContain(AdminPermission.SYSTEM_CONFIG_WRITE);
      expect(perms).not.toContain(AdminPermission.FLEET_WRITE);
    });

    it('10. should restrict READONLY_ANALYST to read-only capabilities with zero mutation permissions', () => {
      const perms = getPermissionsForUser(Role.ADMIN, StaffRole.READONLY_ANALYST);
      expect(perms).toContain(AdminPermission.ANALYTICS_READ);
      expect(perms).toContain(AdminPermission.BOOKING_READ);
      expect(perms).not.toContain(AdminPermission.BOOKING_WRITE);
      expect(perms).not.toContain(AdminPermission.VENDOR_WRITE);
      expect(perms).not.toContain(AdminPermission.PAYOUT_EXECUTE);
      expect(perms).not.toContain(AdminPermission.SYSTEM_CONFIG_WRITE);
    });
  });
});
