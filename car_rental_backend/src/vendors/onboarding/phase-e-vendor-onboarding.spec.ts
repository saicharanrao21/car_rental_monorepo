import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import { AuditLogService } from '../../admin/audit-log.service';
import { VendorOnboardingRequirementsService } from './vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from './vendor-security-deposit.service';
import { VendorOnboardingEligibilityService } from './vendor-onboarding-eligibility.service';
import { VendorsService } from '../vendors.service';
import { NotificationsService } from '../../notifications/notifications.service';
import { BankEncryptionService } from '../../common/bank-encryption.service';
import { UploadsService } from '../../uploads/uploads.service';
import {
  RequirementCategory,
  RequirementScope,
  RequirementFulfillmentStatus,
  VendorDepositStatus,
  VendorDepositTransactionType,
} from './onboarding.types';
import { VerificationStatus, SubscriptionTier, Role } from '@prisma/client';

describe('Phase E — Vendor Onboarding & Security Deposit Management Engine', () => {
  let requirementsService: VendorOnboardingRequirementsService;
  let depositService: VendorSecurityDepositService;
  let eligibilityService: VendorOnboardingEligibilityService;
  let vendorsService: VendorsService;

  let mockPrisma: any;
  let mockCache: any;
  let mockSystemConfig: any;
  let mockAuditLog: any;
  let mockNotifications: any;
  let mockBankEncryption: any;
  let mockUploads: any;

  // In-memory data store for tests
  let vendorsTable: Map<string, any>;
  let definitionsTable: Map<string, any>;
  let statesTable: Map<string, any>;
  let depositsTable: Map<string, any>;
  let ledgerTable: any[];
  let documentsTable: Map<string, any>;
  let auditTable: any[];

  beforeEach(async () => {
    vendorsTable = new Map();
    definitionsTable = new Map();
    statesTable = new Map();
    depositsTable = new Map();
    ledgerTable = [];
    documentsTable = new Map();
    auditTable = [];

    mockCache = {
      get: jest.fn(async () => null),
      set: jest.fn(async () => true),
      delete: jest.fn(async () => true),
    };

    mockAuditLog = {
      log: jest.fn((userId, action, entity, entityId, details) => {
        auditTable.push({ userId, action, entity, entityId, details });
      }),
    };

    mockNotifications = {
      notifyUser: jest.fn(async () => true),
    };

    mockBankEncryption = {
      encrypt: jest.fn((val) => `enc_${val}`),
      decrypt: jest.fn((val) => val.replace('enc_', '')),
      mask: jest.fn((val) => `****${val.slice(-4)}`),
    };

    mockUploads = {
      uploadFile: jest.fn(async () => ({ url: 'https://cdn.drivego.in/doc.pdf' })),
    };

    mockSystemConfig = {
      getConfig: jest.fn(async (key: string) => {
        if (key === 'vendor.onboarding.rules') {
          return {
            defaultSecurityDepositAmount: 25000,
            allowPartialDepositPayment: true,
            minInitialDepositPercentage: 50,
            documentExpiryGracePeriodDays: 7,
            strictActivationEnforcement: true,
            autoCheckEligibilityOnUpload: true,
          };
        }
        return null;
      }),
      getVendorOnboardingConfig: jest.fn(async () => ({
        defaultSecurityDepositAmount: 25000,
        allowPartialDepositPayment: true,
        minInitialDepositPercentage: 50,
        documentExpiryGracePeriodDays: 7,
        strictActivationEnforcement: true,
        autoCheckEligibilityOnUpload: true,
      })),
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
        return list;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `def_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const created = { id, ...data, version: data.version ?? 1, createdAt: new Date(), updatedAt: new Date() };
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
      vendor: {
        findUnique: jest.fn(async ({ where, include }: any) => {
          const v = vendorsTable.get(where.id);
          if (!v) return null;
          const result = { ...v };
          if (include?.cars) {
            result.cars = v.cars || [];
          }
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
      document: {
        findUnique: jest.fn(async ({ where }: any) => {
          return documentsTable.get(where.id) || null;
        }),
        create: jest.fn(async ({ data }: any) => {
          const id = `doc_${Date.now()}`;
          const doc = { id, ...data, uploadedAt: new Date() };
          documentsTable.set(id, doc);
          return doc;
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
      vendorDepositLedger: {
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
      $transaction: jest.fn(async (fn: any) => {
        return fn(mockPrisma);
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VendorOnboardingRequirementsService,
        VendorSecurityDepositService,
        VendorOnboardingEligibilityService,
        VendorsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RedisCacheService, useValue: mockCache },
        { provide: SystemConfigService, useValue: mockSystemConfig },
        { provide: AuditLogService, useValue: mockAuditLog },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: BankEncryptionService, useValue: mockBankEncryption },
        { provide: UploadsService, useValue: mockUploads },
      ],
    }).compile();

    requirementsService = module.get(VendorOnboardingRequirementsService);
    depositService = module.get(VendorSecurityDepositService);
    eligibilityService = module.get(VendorOnboardingEligibilityService);
    vendorsService = module.get(VendorsService);

    // Seed a standard test vendor
    vendorsTable.set('vendor-1', {
      id: 'vendor-1',
      businessName: 'Apex City Fleet',
      ownerName: 'Rajesh Kumar',
      city: 'Hyderabad',
      locality: 'Madhapur',
      gstNumber: '36ABCDE1234F1Z5',
      panNumber: 'ABCDE1234F',
      bankDetails: JSON.stringify({ account: '9191002233', ifsc: 'HDFC0001234' }),
      businessType: 'INDIVIDUAL',
      verificationStatus: VerificationStatus.PENDING,
      subscriptionTier: SubscriptionTier.BASIC,
      cars: [{ id: 'car-1', type: 'SEDAN' }],
      serviceAreaAssignments: [{ serviceAreaId: 'area-hyd-1' }],
    });
  });

  // ==========================================
  // SECTION 1: REQUIREMENT DEFINITIONS & SCOPES
  // ==========================================

  describe('Requirement Definitions Management', () => {
    it('seeds default requirements if table is empty', async () => {
      const seeded = await requirementsService.seedDefaultRequirementDefinitions();
      expect(seeded.length).toBeGreaterThanOrEqual(4);
      expect(definitionsTable.size).toBeGreaterThanOrEqual(4);
    });

    it('creates a custom requirement definition with version 1', async () => {
      const created = await requirementsService.createDefinition(
        {
          code: 'POLLUTION_UNDER_CONTROL',
          title: 'Pollution Under Control (PUC) Certificate',
          category: RequirementCategory.DOCUMENT,
          scope: RequirementScope.GLOBAL,
          isRequired: true,
          requiresAdminReview: true,
          validityDays: 180,
        },
        'admin-user-1',
      );

      expect(created.code).toBe('POLLUTION_UNDER_CONTROL');
      expect(created.version).toBe(1);
      expect(created.isActive).toBe(true);
      expect(mockAuditLog.log).toHaveBeenCalledWith(
        'admin-user-1',
        expect.stringMatching(/REQUIREMENT/),
        expect.stringMatching(/REQUIREMENT/),
        created.id,
        expect.anything(),
      );
    });

    it('increments version when updateDefinition is called with createNewVersion: true', async () => {
      const initial = await requirementsService.createDefinition(
        {
          code: 'GPS_INSTALLATION',
          title: 'Commercial GPS Tracker Proof',
          category: RequirementCategory.PHYSICAL_ASSET,
          scope: RequirementScope.GLOBAL,
          isRequired: true,
        },
        'admin-user-1',
      );

      const updated = await requirementsService.updateDefinition(
        initial.id,
        {
          description: 'Updated requirement for dual-band AIS 140 GPS tracker',
          createNewVersion: true,
        },
        'admin-user-1',
      );

      expect(updated.version).toBe(2);
      expect(updated.description).toContain('AIS 140');
    });

    it('resolves requirements matching global, vehicle category, and service area scopes', async () => {
      // 1. Global doc
      const defGlobal = await requirementsService.createDefinition({
        code: 'PAN_CARD',
        title: 'Vendor PAN Card',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.GLOBAL,
        isRequired: true,
      });

      // 2. Luxury vehicle doc (vendor-1 does not have LUXURY, only SEDAN)
      await requirementsService.createDefinition({
        code: 'LUXURY_PERMIT',
        title: 'Luxury Fleet Commercial Permit',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.VEHICLE_CATEGORY,
        applicableCategory: 'LUXURY',
        isRequired: true,
      });

      // 3. Service area doc for Hyderabad area-hyd-1 (vendor-1 has area-hyd-1)
      const defAreaHyd = await requirementsService.createDefinition({
        code: 'AIRPORT_AUTHORITY_PASS',
        title: 'RGIA Airport Commercial Pass',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.SERVICE_AREA,
        applicableServiceAreaId: 'area-hyd-1',
        isRequired: true,
      });

      // 4. Service area doc for Bangalore (vendor-1 not in area-blr-1)
      await requirementsService.createDefinition({
        code: 'BLR_PASS',
        title: 'Bengaluru Permit',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.SERVICE_AREA,
        applicableServiceAreaId: 'area-blr-1',
        isRequired: true,
      });

      const resolved = await requirementsService.resolveRequirementsForVendor('vendor-1');

      const codes = resolved.map((r: any) => r.code ?? r.definition?.code);
      expect(codes).toContain('PAN_CARD');
      expect(codes).toContain('AIRPORT_AUTHORITY_PASS');
      expect(codes).not.toContain('LUXURY_PERMIT');
      expect(codes).not.toContain('BLR_PASS');
    });
  });

  // ==========================================
  // SECTION 2: FULFILLMENT, REVIEW & WAIVER
  // ==========================================

  describe('Requirement Fulfillment, Admin Review, and Waiver', () => {
    let panDef: any;

    beforeEach(async () => {
      panDef = await requirementsService.createDefinition({
        code: 'PAN_CARD',
        title: 'Vendor PAN Card',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.GLOBAL,
        isRequired: true,
        requiresAdminReview: true,
        validityDays: 365,
      });
    });

    it('allows vendor to submit document fulfillment and transitions to SUBMITTED', async () => {
      const submitted = await requirementsService.submitDocumentFulfillment('vendor-1', {
        requirementDefinitionId: panDef.id,
        fileUrl: 'https://cdn.drivego.in/pan.pdf',
        documentType: 'RC_BOOK' as any,
        expiresAt: new Date(Date.now() + 100 * 24 * 3600 * 1000).toISOString(),
      });

      expect(submitted.status).toBe(RequirementFulfillmentStatus.SUBMITTED);
      expect(submitted.documentId).toBeDefined();
    });

    it('approves requirement fulfillment when admin reviews with APPROVED status', async () => {
      await requirementsService.submitDocumentFulfillment('vendor-1', {
        requirementDefinitionId: panDef.id,
        fileUrl: 'https://cdn.drivego.in/pan.pdf',
        documentType: 'RC_BOOK' as any,
      });

      const reviewed = await requirementsService.reviewRequirement(
        'vendor-1',
        panDef.id,
        {
          decision: RequirementFulfillmentStatus.APPROVED,
          reviewNotes: 'Clear PAN copy verified against NSDL',
        },
        'admin-agent-1',
      );

      expect(reviewed.status).toBe(RequirementFulfillmentStatus.APPROVED);
      expect(reviewed.verifiedAt).toBeDefined();
      expect(reviewed.verifiedBy).toBe('admin-agent-1');
    });

    it('rejects fulfillment with mandatory review notes on rejection', async () => {
      await requirementsService.submitDocumentFulfillment('vendor-1', {
        requirementDefinitionId: panDef.id,
        fileUrl: 'https://cdn.drivego.in/pan_blurry.pdf',
        documentType: 'RC_BOOK' as any,
      });

      const rejected = await requirementsService.reviewRequirement(
        'vendor-1',
        panDef.id,
        {
          decision: RequirementFulfillmentStatus.REJECTED,
          reviewNotes: 'Document is illegible. Please re-upload.',
        },
        'admin-agent-1',
      );

      expect(rejected.status).toBe(RequirementFulfillmentStatus.REJECTED);
      expect(rejected.rejectionReason).toBe('Document is illegible. Please re-upload.');
    });

    it('waives requirement with mandatory reason logged to audit trail', async () => {
      const waived = await requirementsService.waiveRequirement(
        'vendor-1',
        panDef.id,
        { reason: 'Govt enterprise partner exemption approved by operations VP' },
        'admin-director-1',
      );

      expect(waived.status).toBe(RequirementFulfillmentStatus.WAIVED);
      expect(waived.waiverReason).toContain('Govt enterprise partner exemption');
      expect(mockAuditLog.log).toHaveBeenCalledWith(
        'admin-director-1',
        expect.stringMatching(/WAIVE/),
        expect.stringMatching(/REQUIREMENT/),
        expect.anything(),
        expect.objectContaining({ reason: expect.stringContaining('Govt enterprise') }),
      );
    });
  });

  // ==========================================
  // SECTION 3: VENDOR SECURITY DEPOSIT MANAGEMENT
  // ==========================================

  describe('Vendor Security Deposit Ledger & Lifecycle', () => {
    it('initializes deposit with default amount from system config', async () => {
      const dep = await depositService.getDeposit('vendor-1');
      expect(dep.amountRequired).toBe(25000);
      expect(dep.amountPaid).toBe(0);
      expect(dep.status).toBe(VendorDepositStatus.REQUIRED);
    });

    it('rejects initial partial payment below minimum configured percentage (50%)', async () => {
      await expect(
        depositService.recordPayment(
          'vendor-1',
          {
            amount: 5000, // 20% of 25,000, minimum is 50% (12,500)
            paymentMethod: 'UPI',
            referenceId: 'UPI-FAIL-01',
          },
          'admin-1',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('records valid partial payment and creates immutable ledger credit', async () => {
      const result = await depositService.recordPayment(
        'vendor-1',
        {
          amount: 15000, // 60% of 25,000, satisfies >= 50%
          paymentMethod: 'NEFT',
          referenceId: 'NEFT-PARTIAL-123',
        },
        'admin-1',
      );

      expect(result.status).toBe(VendorDepositStatus.PARTIALLY_PAID);
      expect(result.amountPaid).toBe(15000);

      const ledger = await depositService.getLedgerEntries('vendor-1');
      expect(ledger.length).toBe(1);
      expect(ledger[0].transactionType).toBe(VendorDepositTransactionType.INITIAL_PAYMENT);
      expect(ledger[0].amount).toBe(15000);
      expect(ledger[0].balanceAfter).toBe(15000);
    });

    it('transitions deposit to PAID when remaining balance is cleared', async () => {
      // 1. First payment 15,000
      await depositService.recordPayment(
        'vendor-1',
        { amount: 15000, paymentMethod: 'NEFT' },
        'admin-1',
      );

      // 2. Second payment 10,000
      const fullyPaid = await depositService.recordPayment(
        'vendor-1',
        { amount: 10000, paymentMethod: 'UPI' },
        'admin-1',
      );

      expect(fullyPaid.status).toBe(VendorDepositStatus.PAID);
      expect(fullyPaid.amountPaid).toBe(25000);

      const ledger = await depositService.getLedgerEntries('vendor-1');
      expect(ledger.length).toBe(2);
      expect(ledger[1].transactionType).toBe(VendorDepositTransactionType.TOP_UP);
      expect(ledger[1].balanceAfter).toBe(25000);
    });

    it('executes hold, release, refund, and forfeiture transitions with ledger auditing', async () => {
      // Setup fully paid
      await depositService.recordPayment(
        'vendor-1',
        { amount: 25000, paymentMethod: 'BANK_TRANSFER' },
        'admin-1',
      );

      // 1. Hold deposit due to dispute investigation
      const held = await depositService.holdDeposit('vendor-1', 'admin-1');
      expect(held.status).toBe(VendorDepositStatus.HELD);

      // 2. Release hold
      const released = await depositService.releaseDeposit(
        'vendor-1',
        { reason: 'Investigation completed, vendor cleared' },
        'admin-1',
      );
      expect(released.status).toBe(VendorDepositStatus.PAID);

      // 3. Forfeit a portion of deposit for contract breach
      const forfeited = await depositService.forfeitDeposit(
        'vendor-1',
        { amount: 5000, reason: 'Repeated customer cancellation penalties' },
        'admin-1',
      );
      expect(forfeited.amountPaid).toBe(20000);

      // 4. Refund remaining deposit
      const refunded = await depositService.refundDeposit(
        'vendor-1',
        { amount: 20000, reason: 'Vendor offboarding and contract termination' },
        'admin-1',
      );
      expect(refunded.amountPaid).toBe(0);
      expect(refunded.status).toBe(VendorDepositStatus.REFUNDED);
    });
  });

  // ==========================================
  // SECTION 4: READINESS & ACTIVATION GATING
  // ==========================================

  describe('Vendor Activation Gating & Verification Flow', () => {
    it('blocks vendor verification when compliance requirements or deposit are missing', async () => {
      // 1. Add required PAN doc
      await requirementsService.createDefinition({
        code: 'PAN_DOC',
        title: 'PAN Document',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.GLOBAL,
        isRequired: true,
      });

      // 2. Try to verify vendor directly through VendorsService
      await expect(
        vendorsService.updateStatus(
          'vendor-1',
          { status: VerificationStatus.VERIFIED },
          'admin-1',
        ),
      ).rejects.toThrow(BadRequestException);

      const current = vendorsTable.get('vendor-1');
      expect(current.verificationStatus).toBe(VerificationStatus.PENDING);
    });

    it('allows vendor verification when all mandatory requirements and security deposit are fulfilled', async () => {
      // 1. Add required PAN doc
      const panDef = await requirementsService.createDefinition({
        code: 'PAN_DOC',
        title: 'PAN Document',
        category: RequirementCategory.DOCUMENT,
        scope: RequirementScope.GLOBAL,
        isRequired: true,
      });

      // 2. Waive or approve the PAN doc
      await requirementsService.waiveRequirement(
        'vendor-1',
        panDef.id,
        { reason: 'Physical copy verified on-site' },
        'admin-1',
      );

      // 3. Pay security deposit in full
      await depositService.recordPayment(
        'vendor-1',
        { amount: 25000, paymentMethod: 'RTGS' },
        'admin-1',
      );

      // 4. Check eligibility
      const eligibility = await eligibilityService.evaluateEligibility('vendor-1', true);
      expect(eligibility.isEligible).toBe(true);
      expect(eligibility.blockingReasons).toHaveLength(0);

      // 5. Update status through VendorsService to VERIFIED
      const updated = await vendorsService.updateStatus(
        'vendor-1',
        { status: VerificationStatus.VERIFIED },
        'admin-1',
      );

      expect(updated.verificationStatus).toBe(VerificationStatus.VERIFIED);
      expect(mockAuditLog.log).toHaveBeenCalledWith(
        'admin-1',
        'VENDOR_STATUS_UPDATED',
        'Vendor',
        'vendor-1',
        { status: VerificationStatus.VERIFIED },
      );
    });
  });
});
