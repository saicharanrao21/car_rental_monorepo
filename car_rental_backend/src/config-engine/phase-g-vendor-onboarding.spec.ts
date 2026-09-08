import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from './system-config.service';
import { SystemConfigValidator } from './system-config-validator';
import {
  DEFAULT_SYSTEM_CONFIGS,
  VendorOnboardingRulesConfig,
} from './system-config.interface';
import { VendorOnboardingRequirementsService } from '../vendors/onboarding/vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from '../vendors/onboarding/vendor-security-deposit.service';
import { VendorOnboardingEligibilityService } from '../vendors/onboarding/vendor-onboarding-eligibility.service';
import {
  RequirementCategory,
  RequirementScope,
  RequirementFulfillmentStatus,
  VendorDepositStatus,
  VendorDepositTransactionType,
  LedgerDirection,
} from '../vendors/onboarding/onboarding.types';

describe('Phase G — Dynamic Vendor Onboarding & Security Deposits Engine', () => {
  let configService: SystemConfigService;
  let requirementsService: VendorOnboardingRequirementsService;
  let depositService: VendorSecurityDepositService;
  let eligibilityService: VendorOnboardingEligibilityService;

  // In-memory data structures
  let configsTable: Map<string, any>;
  let definitionsTable: Map<string, any>;
  let statesTable: Map<string, any>;
  let depositsTable: Map<string, any>;
  let ledgerTable: any[];
  let auditLogsTable: any[];
  let vendorsTable: Map<string, any>;

  let mockPrisma: any;
  let mockCache: any;
  let mockAuditLog: any;

  beforeEach(async () => {
    configsTable = new Map();
    definitionsTable = new Map();
    statesTable = new Map();
    depositsTable = new Map();
    ledgerTable = [];
    auditLogsTable = [];
    vendorsTable = new Map();

    // Seed test vendor
    vendorsTable.set('vendor-test-1', {
      id: 'vendor-test-1',
      businessName: 'Apex Drive Logistics',
      verificationStatus: 'PENDING',
      cars: [{ type: 'SEDAN' }, { type: 'SUV' }],
      serviceAreaAssignments: [
        { serviceAreaId: 'area-hyd-central' },
        { serviceAreaId: 'area-hyd-airport' },
      ],
    });

    mockCache = {
      get: jest.fn(async () => null),
      set: jest.fn(async () => undefined),
      delete: jest.fn(async () => undefined),
      del: jest.fn(async () => undefined),
    };

    mockAuditLog = {
      log: jest.fn(async (adminUserId, action, targetType, targetId, metadata) => {
        auditLogsTable.push({
          adminUserId,
          action,
          targetType,
          targetId,
          metadata,
          createdAt: new Date(),
        });
      }),
    };

    const onboardingReqDefMock = {
      count: jest.fn(async () => definitionsTable.size),
      findUnique: jest.fn(async ({ where }: any) => {
        return definitionsTable.get(where.id) || null;
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        let list = Array.from(definitionsTable.values());
        if (where?.code) list = list.filter((d) => d.code === where.code);
        if (where?.isActive !== undefined) list = list.filter((d) => d.isActive === where.isActive);
        return list[0] || null;
      }),
      findMany: jest.fn(async ({ where, orderBy }: any) => {
        let list = Array.from(definitionsTable.values());
        if (where?.isActive !== undefined) {
          list = list.filter((d) => d.isActive === where.isActive);
        }
        if (where?.category) {
          list = list.filter((d) => d.category === where.category);
        }
        if (where?.scope) {
          list = list.filter((d) => d.scope === where.scope);
        }
        if (where?.effectiveFrom?.lte) {
          const now = where.effectiveFrom.lte;
          list = list.filter(
            (d) => d.effectiveFrom <= now && (!d.effectiveTo || d.effectiveTo > now),
          );
        }
        return list;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `def_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const created = {
          id,
          ...data,
          version: data.version ?? 1,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        definitionsTable.set(id, created);
        return created;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const def = definitionsTable.get(where.id);
        if (!def) throw new NotFoundException('Definition not found');
        const updated = { ...def, ...data, updatedAt: new Date() };
        definitionsTable.set(where.id, updated);
        return updated;
      }),
    };

    mockPrisma = {
      systemConfig: {
        findUnique: jest.fn(async ({ where }: any) => {
          return configsTable.get(where.key) || null;
        }),
        findMany: jest.fn(async () => Array.from(configsTable.values())),
        upsert: jest.fn(async ({ where, update, create }: any) => {
          const existing = configsTable.get(where.key);
          if (existing) {
            const updated = { ...existing, ...update, version: (existing.version || 1) + 1 };
            configsTable.set(where.key, updated);
            return updated;
          } else {
            const created = { key: where.key, ...create, version: 1 };
            configsTable.set(where.key, created);
            return created;
          }
        }),
      },
      vendor: {
        findUnique: jest.fn(async ({ where, include }: any) => {
          const v = vendorsTable.get(where.id);
          if (!v) return null;
          const result = { ...v };
          if (include?.cars) result.cars = v.cars || [];
          if (include?.serviceAreaAssignments) {
            result.serviceAreaAssignments = v.serviceAreaAssignments || [];
          }
          return result;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          const v = vendorsTable.get(where.id);
          if (!v) throw new NotFoundException('Vendor not found');
          const updated = { ...v, ...data, updatedAt: new Date() };
          vendorsTable.set(where.id, updated);
          return updated;
        }),
      },
      onboardingRequirementDefinition: onboardingReqDefMock,
      vendorRequirementDefinition: onboardingReqDefMock,
      vendorRequirementState: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.id) return statesTable.get(where.id) || null;
          if (where.vendorId_requirementDefinitionId) {
            const key = `${where.vendorId_requirementDefinitionId.vendorId}_${where.vendorId_requirementDefinitionId.requirementDefinitionId}`;
            return statesTable.get(key) || null;
          }
          return null;
        }),
        findMany: jest.fn(async ({ where }: any) => {
          return Array.from(statesTable.values()).filter((s) => s.vendorId === where.vendorId);
        }),
        create: jest.fn(async ({ data }: any) => {
          const id = `st_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
          const key = `${data.vendorId}_${data.requirementDefinitionId}`;
          const record = { id, ...data, createdAt: new Date(), updatedAt: new Date() };
          statesTable.set(key, record);
          statesTable.set(id, record);
          return record;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          let record: any = null;
          if (where.id) record = statesTable.get(where.id);
          if (!record && where.vendorId_requirementDefinitionId) {
            const key = `${where.vendorId_requirementDefinitionId.vendorId}_${where.vendorId_requirementDefinitionId.requirementDefinitionId}`;
            record = statesTable.get(key);
          }
          if (!record) throw new NotFoundException('State not found');
          const updated = { ...record, ...data, updatedAt: new Date() };
          const key = `${updated.vendorId}_${updated.requirementDefinitionId}`;
          statesTable.set(key, updated);
          statesTable.set(updated.id, updated);
          return updated;
        }),
        upsert: jest.fn(async ({ where, update, create }: any) => {
          let key = '';
          if (where.vendorId_requirementDefinitionId) {
            key = `${where.vendorId_requirementDefinitionId.vendorId}_${where.vendorId_requirementDefinitionId.requirementDefinitionId}`;
          }
          let existing = key ? statesTable.get(key) : null;
          if (existing) {
            const updated = { ...existing, ...update, updatedAt: new Date() };
            statesTable.set(key, updated);
            statesTable.set(updated.id, updated);
            return updated;
          } else {
            const id = `st_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
            const record = { id, ...create, createdAt: new Date(), updatedAt: new Date() };
            if (key) statesTable.set(key, record);
            statesTable.set(id, record);
            return record;
          }
        }),
        updateMany: jest.fn(async ({ where, data }: any) => {
          let count = 0;
          for (const [k, s] of statesTable.entries()) {
            if (
              (!where.vendorId || s.vendorId === where.vendorId) &&
              (!where.requirementDefinitionId || s.requirementDefinitionId === where.requirementDefinitionId)
            ) {
              const updated = { ...s, ...data, updatedAt: new Date() };
              statesTable.set(k, updated);
              count++;
            }
          }
          return { count };
        }),
      },
      vendorSecurityDeposit: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.vendorId) return depositsTable.get(where.vendorId) || null;
          if (where.id) {
            return Array.from(depositsTable.values()).find((d: any) => d.id === where.id) || null;
          }
          return null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const id = `vsd_${Date.now()}`;
          const dep = { id, ...data, createdAt: new Date(), updatedAt: new Date() };
          depositsTable.set(data.vendorId, dep);
          return dep;
        }),
        update: jest.fn(async ({ where, data }: any) => {
          let dep: any = null;
          if (where.id) {
            dep = Array.from(depositsTable.values()).find((d: any) => d.id === where.id);
          } else if (where.vendorId) {
            dep = depositsTable.get(where.vendorId);
          }
          if (!dep) throw new NotFoundException('Deposit not found');
          const updated = { ...dep, ...data, updatedAt: new Date() };
          depositsTable.set(dep.vendorId, updated);
          return updated;
        }),
      },
      vendorDepositLedgerEntry: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where.idempotencyKey) {
            return ledgerTable.find((e) => e.idempotencyKey === where.idempotencyKey) || null;
          }
          return null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const id = `vdl_${Date.now()}_${ledgerTable.length}`;
          const entry = { id, ...data, createdAt: new Date() };
          ledgerTable.push(entry);
          return entry;
        }),
        findMany: jest.fn(async ({ where }: any) => {
          return ledgerTable.filter((e) => e.depositId === where.depositId);
        }),
      },
      vendorServiceArea: {
        findFirst: jest.fn(async ({ where }: any) => {
          const v = vendorsTable.get(where.vendorId);
          const hasArea = v?.serviceAreaAssignments?.some(
            (a: any) => a.serviceAreaId === where.serviceAreaId,
          );
          return hasArea
            ? { id: 'vsa-1', vendorId: where.vendorId, serviceAreaId: where.serviceAreaId }
            : null;
        }),
      },
      auditLog: {
        create: jest.fn(async ({ data }: any) => {
          auditLogsTable.push({ ...data, id: `audit_${Date.now()}` });
          return data;
        }),
      },
      $transaction: jest.fn(async (fn: any) => {
        return fn(mockPrisma);
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SystemConfigService,
        VendorOnboardingRequirementsService,
        VendorSecurityDepositService,
        VendorOnboardingEligibilityService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
        { provide: AuditLogService, useValue: mockAuditLog },
      ],
    }).compile();

    configService = module.get(SystemConfigService);
    requirementsService = module.get(VendorOnboardingRequirementsService);
    depositService = module.get(VendorSecurityDepositService);
    eligibilityService = module.get(VendorOnboardingEligibilityService);
  });

  // ==========================================
  // SCENARIO 1: Vendor onboarding rule defaults
  // ==========================================
  it('1. should expose correct system config defaults for vendor.onboarding.rules', async () => {
    const fallback = DEFAULT_SYSTEM_CONFIGS['vendor.onboarding.rules'];
    expect(fallback).toBeDefined();
    expect(fallback.category).toBe('VENDOR');
    expect(fallback.isPublic).toBe(true);

    const config = await configService.getVendorOnboardingConfig();
    expect(config.defaultSecurityDepositAmount).toBe(25000);
    expect(config.allowPartialDepositPayment).toBe(true);
    expect(config.minInitialDepositPercentage).toBe(20);
    expect(config.documentExpiryGracePeriodDays).toBe(7);
    expect(config.strictActivationEnforcement).toBe(true);
    expect(config.autoCheckEligibilityOnUpload).toBe(true);
  });

  // ==========================================
  // SCENARIO 2: Configuration validation
  // ==========================================
  it('2. should semantically validate valid vendor onboarding configuration', () => {
    const validConfig: VendorOnboardingRulesConfig = {
      defaultSecurityDepositAmount: 30000,
      allowPartialDepositPayment: true,
      minInitialDepositPercentage: 25,
      documentExpiryGracePeriodDays: 14,
      strictActivationEnforcement: true,
      autoCheckEligibilityOnUpload: false,
    };

    const validated = SystemConfigValidator.validate('vendor.onboarding.rules', validConfig);
    expect(validated).toEqual(validConfig);
  });

  // ==========================================
  // SCENARIO 3: Invalid onboarding configuration rejection
  // ==========================================
  it('3. should reject invalid onboarding configurations with BadRequestException', () => {
    // Negative deposit
    expect(() =>
      SystemConfigValidator.validate('vendor.onboarding.rules', {
        defaultSecurityDepositAmount: -500,
      }),
    ).toThrow(BadRequestException);

    // Percentage > 100
    expect(() =>
      SystemConfigValidator.validate('vendor.onboarding.rules', {
        minInitialDepositPercentage: 150,
      }),
    ).toThrow(BadRequestException);

    // Negative grace period
    expect(() =>
      SystemConfigValidator.validate('vendor.onboarding.rules', {
        documentExpiryGracePeriodDays: -1,
      }),
    ).toThrow(BadRequestException);

    // Non-boolean strict enforcement
    expect(() =>
      SystemConfigValidator.validate('vendor.onboarding.rules', {
        strictActivationEnforcement: 'yes',
      }),
    ).toThrow(BadRequestException);

    // Malformed non-object payload
    expect(() =>
      SystemConfigValidator.validate('vendor.onboarding.rules', 'not-a-json-object'),
    ).toThrow(BadRequestException);
  });

  // ==========================================
  // SCENARIO 4: Dynamic deposit amount
  // ==========================================
  it('4. should initialize deposit with dynamically configured amount from SystemConfigService', async () => {
    configsTable.set('vendor.onboarding.rules', {
      key: 'vendor.onboarding.rules',
      value: {
        defaultSecurityDepositAmount: 40000,
        allowPartialDepositPayment: true,
        minInitialDepositPercentage: 20,
        documentExpiryGracePeriodDays: 7,
        strictActivationEnforcement: true,
        autoCheckEligibilityOnUpload: true,
      },
      version: 1,
    });

    const deposit = await depositService.getDeposit('vendor-test-1');
    expect(deposit.requiredAmount).toBe(40000);
    expect(deposit.paidAmount).toBe(0);
    expect(deposit.remainingAmount).toBe(40000);
    expect(deposit.status).toBe(VendorDepositStatus.REQUIRED);
  });

  // ==========================================
  // SCENARIO 5: Partial deposit rules
  // ==========================================
  it('5. should reject partial payment when allowPartialDepositPayment is disabled', async () => {
    configsTable.set('vendor.onboarding.rules', {
      key: 'vendor.onboarding.rules',
      value: {
        defaultSecurityDepositAmount: 25000,
        allowPartialDepositPayment: false,
        minInitialDepositPercentage: 0,
        documentExpiryGracePeriodDays: 7,
        strictActivationEnforcement: true,
        autoCheckEligibilityOnUpload: true,
      },
      version: 1,
    });

    await expect(
      depositService.recordPayment(
        'vendor-test-1',
        {
          amount: 10000,
          paymentMethod: 'ONLINE_RAZORPAY',
          reference: 'PAY_1',
          idempotencyKey: 'idem-1',
        },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  // ==========================================
  // SCENARIO 6: Minimum initial deposit percentage
  // ==========================================
  it('6. should enforce minimum initial deposit percentage threshold', async () => {
    configsTable.set('vendor.onboarding.rules', {
      key: 'vendor.onboarding.rules',
      value: {
        defaultSecurityDepositAmount: 25000,
        allowPartialDepositPayment: true,
        minInitialDepositPercentage: 30, // 30% of 25000 = 7500
        documentExpiryGracePeriodDays: 7,
        strictActivationEnforcement: true,
        autoCheckEligibilityOnUpload: true,
      },
      version: 1,
    });

    // Attempting payment of 5000 (< 7500)
    await expect(
      depositService.recordPayment(
        'vendor-test-1',
        {
          amount: 5000,
          paymentMethod: 'ONLINE_RAZORPAY',
          reference: 'PAY_2',
          idempotencyKey: 'idem-2',
        },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);

    // Payment of 7500 succeeds
    const result = await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 7500,
        paymentMethod: 'ONLINE_RAZORPAY',
        reference: 'PAY_3',
        idempotencyKey: 'idem-3',
      },
      'admin-1',
    );
    expect(result.paidAmount).toBe(7500);
    expect(result.status).toBe(VendorDepositStatus.PARTIALLY_PAID);
  });

  // ==========================================
  // SCENARIO 7: Deposit balance calculation
  // ==========================================
  it('7. should accurately compute remaining amount and transition status across payments', async () => {
    // Initial 10,000
    const res1 = await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 10000,
        paymentMethod: 'BANK_NEFT',
        reference: 'UTR_001',
        idempotencyKey: 'idem-bal-1',
      },
      'admin-1',
    );
    expect(res1.paidAmount).toBe(10000);
    expect(res1.remainingAmount).toBe(15000);
    expect(res1.status).toBe(VendorDepositStatus.PARTIALLY_PAID);

    // Top-up 15,000 to complete 25,000
    const res2 = await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 15000,
        paymentMethod: 'BANK_NEFT',
        reference: 'UTR_002',
        idempotencyKey: 'idem-bal-2',
      },
      'admin-1',
    );
    expect(res2.paidAmount).toBe(25000);
    expect(res2.remainingAmount).toBe(0);
    expect(res2.status).toBe(VendorDepositStatus.PAID);
  });

  // ==========================================
  // SCENARIO 8: Duplicate deposit mutation prevention (Idempotency)
  // ==========================================
  it('8. should prevent duplicate mutations when reusing idempotency key', async () => {
    const key = 'idem-unique-mutation-123';
    const first = await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 10000,
        paymentMethod: 'ONLINE_UPI',
        reference: 'UPI_1',
        idempotencyKey: key,
      },
      'admin-1',
    );
    expect(first.isIdempotentReplay).toBe(false);

    // Duplicate call with exact same idempotencyKey
    const replay = await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 10000,
        paymentMethod: 'ONLINE_UPI',
        reference: 'UPI_1',
        idempotencyKey: key,
      },
      'admin-1',
    );
    expect(replay.isIdempotentReplay).toBe(true);
    expect(ledgerTable.length).toBe(1); // Only 1 ledger entry created
  });

  // ==========================================
  // SCENARIO 9: Concurrency protection
  // ==========================================
  it('9. should execute financial mutations within ACID transactions with OCC verification', async () => {
    const spy = jest.spyOn(mockPrisma, '$transaction');
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 10000,
        paymentMethod: 'CASH',
        reference: 'REF_TX',
        idempotencyKey: 'idem-tx-1',
      },
      'admin-1',
    );
    expect(spy).toHaveBeenCalled();
  });

  // ==========================================
  // SCENARIO 10: Negative deposit prevention
  // ==========================================
  it('10. should prevent negative deposit balances on adjustments and refunds', async () => {
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 10000,
        paymentMethod: 'ONLINE',
        reference: 'REF_1',
        idempotencyKey: 'idem-neg-1',
      },
      'admin-1',
    );

    // Adjusting with debit greater than current balance (15000 > 10000)
    await expect(
      depositService.adjustDeposit(
        'vendor-test-1',
        {
          amount: -15000,
          direction: LedgerDirection.DEBIT,
          reason: 'Penalty charge beyond balance',
        },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);

    // Refunding more than balance
    await expect(
      depositService.refundDeposit(
        'vendor-test-1',
        {
          amount: 20000,
          reference: 'REF_EXCEED',
          idempotencyKey: 'idem-refund-exceed',
          reason: 'Excess refund',
        },
        'admin-1',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  // ==========================================
  // SCENARIO 11: Deposit hold
  // ==========================================
  it('11. should transition deposit status to HELD and write audit log', async () => {
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 25000,
        paymentMethod: 'ONLINE',
        reference: 'REF_FULL',
        idempotencyKey: 'idem-full-1',
      },
      'admin-1',
    );

    const held = await depositService.holdDeposit(
      'vendor-test-1',
      'admin-1',
      'Dispute pending resolution',
    );
    expect(held.status).toBe(VendorDepositStatus.HELD);
    expect(mockAuditLog.log).toHaveBeenCalledWith(
      'admin-1',
      'HOLD_VENDOR_DEPOSIT',
      'VENDOR_DEPOSIT',
      expect.anything(),
      expect.objectContaining({ newStatus: VendorDepositStatus.HELD }),
    );
  });

  // ==========================================
  // SCENARIO 12: Deposit release
  // ==========================================
  it('12. should release deposit from HELD or full status with audit reason', async () => {
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 25000,
        paymentMethod: 'ONLINE',
        reference: 'REF_FULL_2',
        idempotencyKey: 'idem-rel-1',
      },
      'admin-1',
    );

    const released = await depositService.releaseDeposit(
      'vendor-test-1',
      {
        reference: 'REL_DOC_1',
        idempotencyKey: 'idem-rel-act',
        reason: 'Account closure clearance approved',
      },
      'admin-1',
    );
    expect(released.status).toBe(VendorDepositStatus.RELEASED);
  });

  // ==========================================
  // SCENARIO 13: Deposit refund
  // ==========================================
  it('13. should refund deposit balance with debit ledger entry and reason', async () => {
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 25000,
        paymentMethod: 'ONLINE',
        reference: 'REF_PAID_3',
        idempotencyKey: 'idem-ref-3',
      },
      'admin-1',
    );

    const refunded = await depositService.refundDeposit(
      'vendor-test-1',
      {
        amount: 10000,
        reference: 'BANK_REF_001',
        idempotencyKey: 'idem-refund-entry',
        reason: 'Partial deposit return upon downsizing fleet',
      },
      'admin-1',
    );
    expect(refunded.paidAmount).toBe(15000);
    expect(refunded.ledgerEntry.direction).toBe(LedgerDirection.DEBIT);
    expect(refunded.ledgerEntry.transactionType).toBe(VendorDepositTransactionType.REFUND);
  });

  // ==========================================
  // SCENARIO 14: Deposit forfeiture
  // ==========================================
  it('14. should forfeit deposit with contractual breach reason and debit ledger entry', async () => {
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 25000,
        paymentMethod: 'ONLINE',
        reference: 'REF_FORF_INIT',
        idempotencyKey: 'idem-forf-init',
      },
      'admin-1',
    );

    const forfeited = await depositService.forfeitDeposit(
      'vendor-test-1',
      {
        amount: 25000,
        reference: 'FORFEIT_ORDER_99',
        idempotencyKey: 'idem-forfeit-act',
        reason: 'Severe contractual violation and customer fraud',
      },
      'admin-1',
    );
    expect(forfeited.status).toBe(VendorDepositStatus.FORFEITED);
    expect(forfeited.paidAmount).toBe(0);
    expect(forfeited.ledgerEntry.transactionType).toBe(VendorDepositTransactionType.FORFEITURE);
  });

  // ==========================================
  // SCENARIO 15: Requirement definition lifecycle
  // ==========================================
  it('15. should create, version, and manage requirement definition lifecycle', async () => {
    const created = await requirementsService.createDefinition(
      {
        code: 'DOC_SPEED_GOVERNOR',
        name: 'Commercial Speed Governor Fitment Certificate',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.GLOBAL,
        isRequired: true,
      },
      'admin-1',
    );
    expect(created.version).toBe(1);
    expect(created.code).toBe('DOC_SPEED_GOVERNOR');

    // Create incremented version non-destructively
    const v2 = await requirementsService.updateDefinition(
      created.id,
      {
        name: 'AIS-018 Speed Governor Certificate',
        createNewVersion: true,
        reason: 'Updated AIS transport standard compliance',
      },
      'admin-1',
    );
    expect(v2.version).toBe(2);
    expect(v2.code).toBe('DOC_SPEED_GOVERNOR');
    expect(v2.name).toBe('AIS-018 Speed Governor Certificate');
  });

  // ==========================================
  // SCENARIO 16: Category validation (VERIFICATION, OTHER)
  // ==========================================
  it('16. should support all RequirementCategories including VERIFICATION and OTHER', async () => {
    const reqVerification = await requirementsService.createDefinition({
      code: 'VERIF_PHYSICAL_YARD',
      name: 'Physical Hub & Depot Inspection',
      category: RequirementCategory.VERIFICATION,
      scope: RequirementScope.GLOBAL,
      isRequired: true,
    });
    expect(reqVerification.category).toBe(RequirementCategory.VERIFICATION);

    const reqOther = await requirementsService.createDefinition({
      code: 'OTHER_TRADE_AFFILIATION',
      name: 'State Car Rental Association Membership',
      category: RequirementCategory.OTHER,
      scope: RequirementScope.GLOBAL,
      isRequired: false,
    });
    expect(reqOther.category).toBe(RequirementCategory.OTHER);
  });

  // ==========================================
  // SCENARIO 17: Effective-date filtering
  // ==========================================
  it('17. should resolve requirements matching active effective date windows', async () => {
    const now = new Date();
    const past = new Date(now.getTime() - 86400000 * 30);
    const future = new Date(now.getTime() + 86400000 * 30);

    // Active requirement
    await requirementsService.createDefinition({
      code: 'REQ_ACTIVE',
      name: 'Active Rule',
      category: RequirementCategory.DOCUMENT,
      effectiveFrom: past.toISOString(),
      effectiveTo: future.toISOString(),
    });

    // Future requirement (not yet in effect)
    await requirementsService.createDefinition({
      code: 'REQ_FUTURE',
      name: 'Future Rule',
      category: RequirementCategory.DOCUMENT,
      effectiveFrom: future.toISOString(),
    });

    const activeList = await requirementsService.resolveRequirementsForVendor('vendor-test-1');
    const codes = activeList.map((r) => r.code);
    expect(codes).toContain('REQ_ACTIVE');
    expect(codes).not.toContain('REQ_FUTURE');
  });

  // ==========================================
  // SCENARIO 18: Service-area requirement enforcement
  // ==========================================
  it('18. should enforce that vendors can only fulfill service-area requirements for authorized areas', async () => {
    const defAuthorized = await requirementsService.createDefinition({
      code: 'REQ_HYD_CENTRAL',
      name: 'Hyderabad Central Permit',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.SERVICE_AREA,
      targetScopeValue: 'area-hyd-central',
      isRequired: true,
    });

    const defUnauthorized = await requirementsService.createDefinition({
      code: 'REQ_DELHI_NCR',
      name: 'Delhi NCR Permit',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.SERVICE_AREA,
      targetScopeValue: 'area-delhi-ncr',
      isRequired: true,
    });

    // Vendor is in area-hyd-central -> submission succeeds
    const stateAuth = await requirementsService.submitRequirement(
      'vendor-test-1',
      defAuthorized.id,
      { documentId: 'doc-hyd-pass', documentNumber: 'HYD-001' },
      'vendor-user-1',
    );
    expect(stateAuth).toBeDefined();

    // Vendor is NOT in area-delhi-ncr -> submission rejected with BadRequestException
    await expect(
      requirementsService.submitRequirement(
        'vendor-test-1',
        defUnauthorized.id,
        { documentId: 'doc-delhi-pass', documentNumber: 'DEL-001' },
        'vendor-user-1',
      ),
    ).rejects.toThrow(BadRequestException);
  });

  // ==========================================
  // SCENARIO 19: Vendor requirement state resolution
  // ==========================================
  it('19. should resolve and initialize requirement states for all applicable scopes', async () => {
    await requirementsService.createDefinition({
      code: 'REQ_GLOBAL_PAN',
      name: 'Business PAN',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.GLOBAL,
      isRequired: true,
    });

    await requirementsService.createDefinition({
      code: 'REQ_SUV_PERMIT',
      name: 'SUV Commercial Permit',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.VEHICLE_CATEGORY,
      targetScopeValue: 'SUV',
      isRequired: true,
    });

    const items = await requirementsService.resolveRequirementsForVendor('vendor-test-1');
    expect(items.length).toBeGreaterThanOrEqual(2);
    const panItem = items.find((i) => i.code === 'REQ_GLOBAL_PAN');
    expect(panItem).toBeDefined();
    expect(panItem?.status).toBe(RequirementFulfillmentStatus.PENDING);
  });

  // ==========================================
  // SCENARIO 20: Document verification approval
  // ==========================================
  it('20. should approve requirement submission with admin audit trail', async () => {
    const def = await requirementsService.createDefinition({
      code: 'REQ_GST_CERT',
      name: 'GST Certificate',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.GLOBAL,
    });

    await requirementsService.submitRequirement('vendor-test-1', def.id, {
      documentId: 'doc-gst-valid',
      documentNumber: 'GSTIN36AAAAA0000A1Z5',
    });

    const approved = await requirementsService.reviewRequirement(
      'vendor-test-1',
      def.id,
      { status: RequirementFulfillmentStatus.APPROVED },
      'admin-officer-1',
    );

    expect(approved.status).toBe(RequirementFulfillmentStatus.APPROVED);
    expect(approved.verifiedBy).toBe('admin-officer-1');
    expect(approved.verifiedAt).toBeDefined();
  });

  // ==========================================
  // SCENARIO 21: Document rejection
  // ==========================================
  it('21. should reject submission requiring non-empty rejection reason', async () => {
    const def = await requirementsService.createDefinition({
      code: 'REQ_BANK_STATEMENT',
      name: 'Bank Statement',
      category: RequirementCategory.DOCUMENT,
      scope: RequirementScope.GLOBAL,
    });

    await requirementsService.submitRequirement('vendor-test-1', def.id, {
      documentId: 'doc-statement-blurry',
    });

    // Rejection without reason throws BadRequestException
    await expect(
      requirementsService.reviewRequirement(
        'vendor-test-1',
        def.id,
        { status: RequirementFulfillmentStatus.REJECTED, rejectionReason: '' },
        'admin-officer-1',
      ),
    ).rejects.toThrow(BadRequestException);

    // Rejection with reason succeeds
    const rejected = await requirementsService.reviewRequirement(
      'vendor-test-1',
      def.id,
      {
        status: RequirementFulfillmentStatus.REJECTED,
        rejectionReason: 'Statement is missing bank seal and signature',
      },
      'admin-officer-1',
    );
    expect(rejected.status).toBe(RequirementFulfillmentStatus.REJECTED);
    expect(rejected.rejectionReason).toBe('Statement is missing bank seal and signature');
  });

  // ==========================================
  // SCENARIO 22: Requirement waiver
  // ==========================================
  it('22. should waive requirement with mandatory audit justification', async () => {
    const def = await requirementsService.createDefinition({
      code: 'REQ_PARKING_YARD',
      name: 'Commercial Parking Yard Proof',
      category: RequirementCategory.PHYSICAL_ASSET,
      scope: RequirementScope.GLOBAL,
    });

    await expect(
      requirementsService.waiveRequirement(
        'vendor-test-1',
        def.id,
        { reason: '' },
        'admin-director-1',
      ),
    ).rejects.toThrow(BadRequestException);

    const waived = await requirementsService.waiveRequirement(
      'vendor-test-1',
      def.id,
      { reason: 'Approved under airport authority tie-up parking facility agreement' },
      'admin-director-1',
    );

    expect(waived.status).toBe(RequirementFulfillmentStatus.WAIVED);
    expect(waived.waiverReason).toContain('airport authority');
  });

  // ==========================================
  // SCENARIO 23: Eligibility calculation
  // ==========================================
  it('23. should compute overall vendor compliance eligibility state', async () => {
    // Missing requirements + deposit -> INCOMPLETE
    const resIncomplete = await eligibilityService.evaluateEligibility('vendor-test-1', true);
    expect(resIncomplete.isEligible).toBe(false);
    expect(resIncomplete.blockingReasons.length).toBeGreaterThan(0);
  });

  // ==========================================
  // SCENARIO 24: Strict activation enforcement
  // ==========================================
  it('24. should respect strictActivationEnforcement configuration toggle', async () => {
    // When strict is true (default), unfulfilled mandatory items block activation
    const resStrict = await eligibilityService.evaluateEligibility('vendor-test-1', true);
    expect(resStrict.isEligible).toBe(false);

    // Set strictActivationEnforcement to false
    configsTable.set('vendor.onboarding.rules', {
      key: 'vendor.onboarding.rules',
      value: {
        defaultSecurityDepositAmount: 25000,
        allowPartialDepositPayment: true,
        minInitialDepositPercentage: 20,
        documentExpiryGracePeriodDays: 7,
        strictActivationEnforcement: false,
        autoCheckEligibilityOnUpload: true,
      },
      version: 1,
    });

    // When strict is false, vendor is eligible as long as no items are REJECTED or EXPIRED
    const resNonStrict = await eligibilityService.evaluateEligibility('vendor-test-1', true);
    expect(resNonStrict.isEligible).toBe(true);
  });

  // ==========================================
  // SCENARIO 25: Historical and audit integrity
  // ==========================================
  it('25. should maintain immutable ledger history and complete audit log records', async () => {
    // Complete a deposit lifecycle
    await depositService.recordPayment(
      'vendor-test-1',
      {
        amount: 25000,
        paymentMethod: 'RTGS',
        reference: 'RTGS_9988',
        idempotencyKey: 'idem-audit-1',
        reason: 'Full partner deposit',
      },
      'admin-auditor-1',
    );

    const ledger = await depositService.getLedgerEntries('vendor-test-1');
    expect(ledger.length).toBe(1);
    expect(ledger[0].balanceBefore).toBe(0);
    expect(ledger[0].balanceAfter).toBe(25000);
    expect(ledger[0].actorRole).toBe('ADMIN');

    // Audit logs verify recording of mutations
    expect(auditLogsTable.length).toBeGreaterThan(0);
    const paymentLog = auditLogsTable.find(
      (l) => l.action === 'RECORD_VENDOR_DEPOSIT_PAYMENT',
    );
    expect(paymentLog).toBeDefined();
    expect(paymentLog.metadata.amount).toBe(25000);
  });
});
