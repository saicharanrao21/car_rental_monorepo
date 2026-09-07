import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, ForbiddenException, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { SystemConfigService } from './system-config.service';
import { SystemConfigController } from './system-config.controller';
import { SystemConfigValidator } from './system-config-validator';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';

describe('Phase C — Admin Configuration Management & Hardening Engine', () => {
  let systemConfigService: SystemConfigService;
  let systemConfigController: SystemConfigController;
  let rolesGuard: RolesGuard;
  let permissionsGuard: PermissionsGuard;
  let reflector: Reflector;

  let dbStore: Map<string, any>;
  let cacheStore: Map<string, any>;
  let auditLogs: any[];
  let mockPrisma: any;
  let mockCache: any;

  beforeEach(async () => {
    dbStore = new Map<string, any>();
    cacheStore = new Map<string, any>();
    auditLogs = [];

    mockCache = {
      get: jest.fn(async (key: string) => cacheStore.get(key) || null),
      set: jest.fn(async (key: string, val: any) => {
        cacheStore.set(key, val);
        return true;
      }),
      delete: jest.fn(async (key: string) => {
        cacheStore.delete(key);
        return true;
      }),
    };

    mockPrisma = {
      systemConfig: {
        findUnique: jest.fn(async ({ where }: { where: { key: string } }) => {
          const record = dbStore.get(where.key);
          if (record === undefined) return null;
          return {
            id: `cfg_${where.key}`,
            key: where.key,
            value: record.value ?? record,
            category: record.category ?? 'PRICING',
            description: record.description ?? 'Test description',
            isPublic: record.isPublic ?? false,
            updatedBy: record.updatedBy ?? 'system',
            createdAt: record.createdAt ?? new Date('2026-09-01T00:00:00.000Z'),
            updatedAt: record.updatedAt ?? new Date('2026-09-01T00:00:00.000Z'),
          };
        }),
        findMany: jest.fn(async () => {
          const list: any[] = [];
          for (const [k, v] of dbStore.entries()) {
            list.push({
              id: `cfg_${k}`,
              key: k,
              value: v.value ?? v,
              category: v.category ?? 'PRICING',
              description: v.description ?? 'Test description',
              isPublic: v.isPublic ?? false,
              updatedBy: v.updatedBy ?? 'system',
              createdAt: v.createdAt ?? new Date(),
              updatedAt: v.updatedAt ?? new Date(),
            });
          }
          return list;
        }),
        upsert: jest.fn(
          async ({
            where,
            create,
            update,
          }: {
            where: { key: string };
            create: any;
            update: any;
          }) => {
            const val = update.value ?? create.value;
            const updated = {
              id: `cfg_${where.key}`,
              key: where.key,
              value: val,
              category: create.category ?? 'PRICING',
              description: create.description ?? 'Test description',
              isPublic: create.isPublic ?? false,
              updatedBy: update.updatedBy ?? create.updatedBy ?? 'system',
              createdAt: new Date(),
              updatedAt: new Date(),
            };
            dbStore.set(where.key, updated);
            return updated;
          },
        ),
      },
      auditLog: {
        create: jest.fn(async ({ data }: { data: any }) => {
          const entry = {
            id: `audit_${Date.now()}_${auditLogs.length}`,
            ...data,
            createdAt: new Date(),
          };
          auditLogs.push(entry);
          return entry;
        }),
        findMany: jest.fn(async ({ where }: { where: { targetType: string; targetId: string } }) => {
          return auditLogs
            .filter((l) => l.targetType === where.targetType && l.targetId === where.targetId)
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        }),
        count: jest.fn(async ({ where }: { where: { targetType: string; targetId: string } }) => {
          return auditLogs.filter(
            (l) => l.targetType === where.targetType && l.targetId === where.targetId,
          ).length;
        }),
      },
      user: {
        findUnique: jest.fn(async ({ where }: { where: { id: string } }) => {
          if (where.id.startsWith('adm_')) {
            return { id: where.id, name: 'Admin User', email: 'admin@drivego.com', role: Role.ADMIN };
          }
          return null;
        }),
        findFirst: jest.fn(async () => ({
          id: 'adm_fallback',
          name: 'Fallback Admin',
          email: 'fallback@drivego.com',
          role: Role.ADMIN,
        })),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SystemConfigController],
      providers: [
        SystemConfigService,
        Reflector,
        RolesGuard,
        PermissionsGuard,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
      ],
    }).compile();

    systemConfigService = module.get<SystemConfigService>(SystemConfigService);
    systemConfigController = module.get<SystemConfigController>(SystemConfigController);
    rolesGuard = module.get<RolesGuard>(RolesGuard);
    permissionsGuard = module.get<PermissionsGuard>(PermissionsGuard);
    reflector = module.get<Reflector>(Reflector);
  });

  describe('1. Admin Configuration Read API & Effective Value Resolution', () => {
    it('distinguishes DEFAULT_FALLBACK from DATABASE source', async () => {
      // 1. Without DB record: returns DEFAULT_FALLBACK with isExplicitlyConfigured: false
      const fallbackResult = await systemConfigService.getDetailedConfig('pricing.tax');
      expect(fallbackResult.key).toBe('pricing.tax');
      expect(fallbackResult.effectiveValue).toEqual({ gstRate: 18 });
      expect(fallbackResult.source).toBe('DEFAULT_FALLBACK');
      expect(fallbackResult.isExplicitlyConfigured).toBe(false);
      expect(fallbackResult.version).toBe(1);

      // 2. With DB record: returns DATABASE with isExplicitlyConfigured: true
      await systemConfigService.setConfig('pricing.tax', { gstRate: 12 }, 'adm_1');
      const dbResult = await systemConfigService.getDetailedConfig('pricing.tax');
      expect(dbResult.key).toBe('pricing.tax');
      expect(dbResult.effectiveValue).toEqual({ gstRate: 12 });
      expect(dbResult.source).toBe('DATABASE');
      expect(dbResult.isExplicitlyConfigured).toBe(true);
      expect(dbResult.version).toBe(2);
      expect(dbResult.updatedBy).toBe('adm_1');
    });

    it('getAllDetailedConfigs returns comprehensive configuration tower', async () => {
      const all = await systemConfigController.getAllDetailedConfigs();
      expect(Array.isArray(all)).toBe(true);
      expect(all.length).toBeGreaterThanOrEqual(10);

      const tax = all.find((c) => c.key === 'pricing.tax');
      expect(tax).toBeDefined();
      expect(tax?.isPublic).toBe(true);

      const comm = all.find((c) => c.key === 'pricing.commission');
      expect(comm).toBeDefined();
      expect(comm?.isPublic).toBe(false);
    });

    it('retrieves single configuration via admin endpoint', async () => {
      const quote = await systemConfigController.getConfigByKey('pricing.quote');
      expect(quote).toEqual({ validityMinutes: 15 });
    });
  });

  describe('2. Strict Configuration Schema & Semantic Validation', () => {
    it('validates GST rate: rejects negative or >100% or non-numeric', () => {
      expect(() => SystemConfigValidator.validate('pricing.tax', { gstRate: -1 })).toThrow(
        BadRequestException,
      );
      expect(() => SystemConfigValidator.validate('pricing.tax', { gstRate: 101 })).toThrow(
        BadRequestException,
      );
      expect(() => SystemConfigValidator.validate('pricing.tax', { gstRate: 'invalid' })).toThrow(
        BadRequestException,
      );
      expect(() => SystemConfigValidator.validate('pricing.tax', {})).toThrow(BadRequestException);

      const valid = SystemConfigValidator.validate('pricing.tax', { gstRate: 18 });
      expect(valid.gstRate).toBe(18);
    });

    it('validates quote validity minutes: rejects 0, negative, >1440, or non-integer', () => {
      expect(() => SystemConfigValidator.validate('pricing.quote', { validityMinutes: 0 })).toThrow(
        BadRequestException,
      );
      expect(() => SystemConfigValidator.validate('pricing.quote', { validityMinutes: 2000 })).toThrow(
        BadRequestException,
      );
      expect(() => SystemConfigValidator.validate('pricing.quote', { validityMinutes: 15.5 })).toThrow(
        BadRequestException,
      );

      const valid = SystemConfigValidator.validate('pricing.quote', { validityMinutes: 30 });
      expect(valid.validityMinutes).toBe(30);
    });

    it('validates duration discounts: rejects contradictory / non-monotonic tier discounts', () => {
      // 30 days has lower discount (5%) than 7 days (10%) -> contradictory!
      const contradictory = [
        { minDays: 7, discountPercent: 10 },
        { minDays: 30, discountPercent: 5 },
      ];
      expect(() =>
        SystemConfigValidator.validate('pricing.duration_discounts', contradictory),
      ).toThrow(BadRequestException);

      // Duplicate threshold days
      const duplicateDays = [
        { minDays: 7, discountPercent: 10 },
        { minDays: 7, discountPercent: 15 },
      ];
      expect(() =>
        SystemConfigValidator.validate('pricing.duration_discounts', duplicateDays),
      ).toThrow(BadRequestException);

      // Valid monotonic tiers
      const valid = SystemConfigValidator.validate('pricing.duration_discounts', [
        { minDays: 7, discountPercent: 10 },
        { minDays: 14, discountPercent: 15 },
        { minDays: 30, discountPercent: 25 },
      ]);
      expect(valid.length).toBe(3);
    });

    it('validates cancellation matrix: rejects inverted fee progression', () => {
      // Fee cannot decrease as pickup approaches (e.g. 50% fee at 24h, but only 10% fee at 6h!)
      const invertedFees = {
        tiers: [
          { minHoursBeforePickup: 24, feePercent: 50, tier: 'TIER_A', description: 'Early' },
          { minHoursBeforePickup: 6, feePercent: 10, tier: 'TIER_B', description: 'Late' },
        ],
        afterStartFeePercent: 100,
      };
      expect(() =>
        SystemConfigValidator.validate('booking.cancellation_matrix', invertedFees),
      ).toThrow(BadRequestException);

      // afterStart fee cannot be lower than pre-trip cancellation fee
      const invalidAfterStart = {
        tiers: [
          { minHoursBeforePickup: 24, feePercent: 0, tier: 'TIER_A', description: 'Free' },
          { minHoursBeforePickup: 0, feePercent: 50, tier: 'TIER_B', description: 'Late' },
        ],
        afterStartFeePercent: 25, // Lower than 50%!
      };
      expect(() =>
        SystemConfigValidator.validate('booking.cancellation_matrix', invalidAfterStart),
      ).toThrow(BadRequestException);

      // Duplicate minHoursBeforePickup
      const duplicateHours = {
        tiers: [
          { minHoursBeforePickup: 24, feePercent: 10, tier: 'T1', description: 'D1' },
          { minHoursBeforePickup: 24, feePercent: 20, tier: 'T2', description: 'D2' },
        ],
        afterStartFeePercent: 100,
      };
      expect(() =>
        SystemConfigValidator.validate('booking.cancellation_matrix', duplicateHours),
      ).toThrow(BadRequestException);
    });

    it('validates commission: rejects negative or >100%', () => {
      expect(() =>
        SystemConfigValidator.validate('pricing.commission', { defaultPercent: -5 }),
      ).toThrow(BadRequestException);
      expect(() =>
        SystemConfigValidator.validate('pricing.commission', { defaultPercent: 105 }),
      ).toThrow(BadRequestException);

      const valid = SystemConfigValidator.validate('pricing.commission', { defaultPercent: 15 });
      expect(valid.defaultPercent).toBe(15);
    });

    it('validates deposit defaults: rejects negative or missing standard categories', () => {
      // Negative deposit
      expect(() =>
        SystemConfigValidator.validate('deposits.defaults', {
          HATCHBACK: 3000,
          SEDAN: -500,
          SUV: 5000,
          LUXURY: 10000,
        }),
      ).toThrow(BadRequestException);

      // Missing required LUXURY category
      expect(() =>
        SystemConfigValidator.validate('deposits.defaults', {
          HATCHBACK: 3000,
          SEDAN: 4000,
          SUV: 5000,
        }),
      ).toThrow(BadRequestException);
    });
  });

  describe('3. Safe Concurrency (Optimistic Concurrency Control — OCC)', () => {
    it('accepts update when expectedVersion matches current version', async () => {
      // Initial state is default -> current version 1
      const res = await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 12, expectedVersion: 1 },
        { user: { id: 'adm_1' }, ip: '127.0.0.1' },
      );

      expect(res).toBeDefined();
      expect(res.value.gstRate).toBe(12);
      expect(res.value._version).toBe(2);
    });

    it('rejects update with 409 Conflict when expectedVersion does not match (lost-update prevention)', async () => {
      // First update moves version from 1 to 2
      await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 12, expectedVersion: 1 },
        { user: { id: 'adm_1' } },
      );

      // Second administrator tries to update using stale version 1
      await expect(
        systemConfigController.updateConfig(
          'pricing.tax',
          { gstRate: 15, expectedVersion: 1 },
          { user: { id: 'adm_2' } },
        ),
      ).rejects.toThrow(ConflictException);

      // Administrator with updated version 2 succeeds
      const successfulUpdate = await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 15, expectedVersion: 2 },
        { user: { id: 'adm_2' } },
      );
      expect(successfulUpdate.value.gstRate).toBe(15);
      expect(successfulUpdate.value._version).toBe(3);
    });
  });

  describe('4. Immutable Audit History Creation & Traceability', () => {
    it('creates an immutable audit log record with previous and new values on mutation', async () => {
      await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 28, reason: 'Govt GST slab revision' },
        { user: { id: 'adm_super' }, ip: '10.0.0.1' },
      );

      expect(auditLogs.length).toBe(1);
      const audit = auditLogs[0];
      expect(audit.targetType).toBe('SYSTEM_CONFIG');
      expect(audit.targetId).toBe('pricing.tax');
      expect(audit.action).toBe('CONFIG_UPDATED');
      expect(audit.adminUserId).toBe('adm_super');
      expect(audit.metadata.previousValue).toEqual({ gstRate: 18 }); // Hardcoded default was 18
      expect(audit.metadata.newValue).toEqual({ gstRate: 28 });
      expect(audit.metadata.reason).toBe('Govt GST slab revision');
      expect(audit.metadata.ip).toBe('10.0.0.1');

      // Query audit history via controller endpoint
      const history = await systemConfigController.getConfigAuditHistory('pricing.tax');
      expect(history.length).toBe(1);
      expect(history[0].previousValue).toEqual({ gstRate: 18 });
      expect(history[0].newValue).toEqual({ gstRate: 28 });
    });
  });

  describe('5. Batch Configuration Updates', () => {
    it('executes batch update safely with up-front validation', async () => {
      const batchResult = await systemConfigController.updateConfigsBatch(
        {
          configs: [
            { key: 'pricing.tax', value: { gstRate: 12 }, expectedVersion: 1 },
            { key: 'pricing.quote', value: { validityMinutes: 20 }, expectedVersion: 1 },
          ],
          reason: 'Periodic policy tuning',
        },
        { user: { id: 'adm_1' } },
      );

      expect(batchResult.success).toBe(true);
      expect(batchResult.updatedCount).toBe(2);
      expect(batchResult.updatedKeys).toEqual(['pricing.tax', 'pricing.quote']);

      const tax = await systemConfigService.getConfig<any>('pricing.tax');
      const quote = await systemConfigService.getConfig<any>('pricing.quote');
      expect(tax.gstRate).toBe(12);
      expect(quote.validityMinutes).toBe(20);
    });

    it('rejects entire batch if any item has schema validation failure', async () => {
      await expect(
        systemConfigController.updateConfigsBatch(
          {
            configs: [
              { key: 'pricing.tax', value: { gstRate: 12 } },
              { key: 'pricing.quote', value: { validityMinutes: -50 } }, // Invalid!
            ],
          },
          { user: { id: 'adm_1' } },
        ),
      ).rejects.toThrow(BadRequestException);

      // Neither was persisted
      expect(dbStore.has('pricing.tax')).toBe(false);
    });
  });

  describe('6. Public vs Internal Security Isolation', () => {
    it('public config endpoint never exposes internal-only configs like pricing.commission', async () => {
      const publicConfigs = await systemConfigController.getPublicConfigs();

      // pricing.commission is strictly internal
      expect(publicConfigs['pricing.commission']).toBeUndefined();
      expect(publicConfigs['growth.campaigns']).toBeUndefined();
      expect(publicConfigs['payout.rules']).toBeUndefined();
      expect(publicConfigs['reconciliation.rules']).toBeUndefined();
      expect(publicConfigs['support.sla']).toBeUndefined();

      // Public-safe configs are exposed
      expect(publicConfigs['pricing.tax']).toBeDefined();
      expect(publicConfigs['pricing.quote']).toBeDefined();
      expect(publicConfigs['pricing.duration_discounts']).toBeDefined();
      expect(publicConfigs['booking.cancellation_matrix']).toBeDefined();
      expect(publicConfigs['deposits.defaults']).toBeDefined();
    });
  });

  describe('7. RBAC & Administrative Authorization Enforcement', () => {
    function createMockContext(user: any): ExecutionContext {
      return {
        switchToHttp: () => ({
          getRequest: () => ({ user }),
        }),
        getHandler: () => ({}),
        getClass: () => ({}),
      } as unknown as ExecutionContext;
    }

    it('RolesGuard rejects unauthenticated or customer/vendor users from mutating configs', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue([Role.ADMIN]);

      // Unauthenticated (no user context)
      expect(() => rolesGuard.canActivate(createMockContext(null))).toThrow(ForbiddenException);

      // Customer role
      expect(() => rolesGuard.canActivate(createMockContext({ id: 'cust_1', role: Role.CUSTOMER }))).toThrow(
        ForbiddenException,
      );

      // Vendor role
      expect(() => rolesGuard.canActivate(createMockContext({ id: 'vend_1', role: Role.VENDOR }))).toThrow(
        ForbiddenException,
      );

      // Admin role allowed
      const isAllowed = rolesGuard.canActivate(createMockContext({ id: 'adm_1', role: Role.ADMIN }));
      expect(isAllowed).toBe(true);
    });

    it('PermissionsGuard requires SYSTEM_CONFIG_WRITE permission for mutations', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue([AdminPermission.SYSTEM_CONFIG_WRITE]);

      // Customer does not possess SYSTEM_CONFIG_WRITE
      expect(() =>
        permissionsGuard.canActivate(createMockContext({ id: 'cust_1', role: Role.CUSTOMER })),
      ).toThrow(ForbiddenException);

      // Platform Admin possesses all administrative permissions
      const isAllowed = permissionsGuard.canActivate(
        createMockContext({ id: 'adm_1', role: Role.ADMIN }),
      );
      expect(isAllowed).toBe(true);
    });
  });

  describe('8. Cache Invalidation Integrity on Admin Mutation', () => {
    it('mutations immediately invalidate Redis cache and populate fresh DB values', async () => {
      // Seed cache with 18%
      cacheStore.set('cache:config:pricing.tax', { gstRate: 18 });
      expect((await systemConfigService.getConfig<any>('pricing.tax')).gstRate).toBe(18);

      // Admin updates to 12%
      await systemConfigController.updateConfig(
        'pricing.tax',
        { gstRate: 12 },
        { user: { id: 'adm_1' } },
      );

      // Cache delete was called
      expect(mockCache.delete).toHaveBeenCalledWith('cache:config:pricing.tax');

      // Subsequent read fetches fresh 12% from DB
      const fresh = await systemConfigService.getConfig<any>('pricing.tax');
      expect(fresh.gstRate).toBe(12);
    });
  });
});
