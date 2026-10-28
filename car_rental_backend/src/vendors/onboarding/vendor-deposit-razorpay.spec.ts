import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VendorSecurityDepositService } from './vendor-security-deposit.service';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { AuditLogService } from '../../admin/audit-log.service';
import {
  VendorDepositStatus,
  RequirementFulfillmentStatus,
} from './onboarding.types';
import * as crypto from 'crypto';

describe('Vendor Security Deposit - Razorpay & Policy Management Suite', () => {
  let service: VendorSecurityDepositService;
  let prisma: any;
  let auditLog: any;

  // In-memory data store for tests
  let policies: any[] = [];
  let deposits: Map<string, any> = new Map();
  let ledgerEntries: any[] = [];
  let requirementStates: Map<string, any> = new Map();
  let requirementDefinitions: any[] = [];
  let vendors: Map<string, any> = new Map();

  const MOCK_KEY_SECRET = 'test_secret_for_sha256_mock';

  beforeEach(async () => {
    policies = [];
    deposits = new Map();
    ledgerEntries = [];
    requirementStates = new Map();
    vendors = new Map();

    requirementDefinitions = [
      {
        id: 'req_def_sec_dep',
        code: 'DEP_SECURITY',
        name: 'Partner Security Deposit',
        isActive: true,
      },
    ];

    vendors.set('vendor_101', {
      id: 'vendor_101',
      businessName: 'Apex Mobility Ventures',
      user: {
        id: 'usr_101',
        name: 'Arjun Verma',
        email: 'arjun@apexmobility.in',
        phone: '+919876543210',
      },
    });

    prisma = {
      vendorDepositPolicy: {
        findFirst: jest.fn(async ({ where, orderBy }) => {
          let list = [...policies];
          if (where?.isActive !== undefined) {
            list = list.filter((p) => p.isActive === where.isActive);
          }
          if (orderBy?.version === 'desc') {
            list.sort((a, b) => b.version - a.version);
          }
          return list[0] || null;
        }),
        create: jest.fn(async ({ data }) => {
          const item = { id: `pol_${Date.now()}_${Math.random()}`, ...data };
          policies.push(item);
          return item;
        }),
        updateMany: jest.fn(async ({ where, data }) => {
          let count = 0;
          for (const p of policies) {
            if (where?.isActive !== undefined && p.isActive === where.isActive) {
              Object.assign(p, data);
              count++;
            }
          }
          return { count };
        }),
      },
      vendorSecurityDeposit: {
        findUnique: jest.fn(async ({ where }) => {
          return deposits.get(where.vendorId) || null;
        }),
        findFirst: jest.fn(async ({ where }) => {
          for (const d of deposits.values()) {
            if (where?.OR) {
              for (const cond of where.OR) {
                if (cond.providerOrderId && d.providerOrderId === cond.providerOrderId) return d;
                if (cond.providerPaymentId && d.providerPaymentId === cond.providerPaymentId) return d;
              }
            }
          }
          return null;
        }),
        create: jest.fn(async ({ data }) => {
          const item = { id: `dep_${Date.now()}`, ...data };
          deposits.set(data.vendorId, item);
          return item;
        }),
        update: jest.fn(async ({ where, data }) => {
          let target: any = null;
          for (const d of deposits.values()) {
            if (d.id === where.id || d.vendorId === where.vendorId) {
              target = d;
              break;
            }
          }
          if (target) {
            Object.assign(target, data);
            return target;
          }
          return null;
        }),
      },
      vendorDepositLedgerEntry: {
        findFirst: jest.fn(async ({ where }) => {
          return ledgerEntries.find((e) => e.reference === where?.reference) || null;
        }),
        findUnique: jest.fn(async ({ where }) => {
          return ledgerEntries.find((e) => e.idempotencyKey === where?.idempotencyKey) || null;
        }),
        create: jest.fn(async ({ data }) => {
          const item = { id: `led_${Date.now()}_${Math.random()}`, ...data, createdAt: new Date() };
          ledgerEntries.push(item);
          return item;
        }),
      },
      onboardingRequirementDefinition: {
        findFirst: jest.fn(async ({ where }) => {
          return requirementDefinitions.find(
            (r) => r.code === where.code && (where.isActive === undefined || r.isActive === where.isActive),
          ) || null;
        }),
      },
      vendorRequirementState: {
        upsert: jest.fn(async ({ where, update, create }) => {
          const key = `${where.vendorId_requirementDefinitionId.vendorId}_${where.vendorId_requirementDefinitionId.requirementDefinitionId}`;
          let existing = requirementStates.get(key);
          if (existing) {
            Object.assign(existing, update);
            return existing;
          } else {
            const item = { id: `vrs_${Date.now()}`, ...create };
            requirementStates.set(key, item);
            return item;
          }
        }),
      },
      vendor: {
        findUnique: jest.fn(async ({ where }) => {
          return vendors.get(where.id) || null;
        }),
      },
      $transaction: jest.fn(async (callback) => {
        return callback(prisma);
      }),
    };

    const mockConfigService = {
      get: jest.fn((key: string) => {
        if (key === 'RAZORPAY_KEY_ID') return 'rzp_test_DriveGoVendorKey';
        if (key === 'RAZORPAY_KEY_SECRET') return MOCK_KEY_SECRET;
        if (key === 'RAZORPAY_USE_MOCK') return 'false';
        if (key === 'NODE_ENV') return 'test';
        return null;
      }),
    };

    const mockCacheService = {
      get: jest.fn(),
      set: jest.fn(),
      delete: jest.fn(),
    };

    auditLog = {
      log: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VendorSecurityDepositService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: RedisCacheService, useValue: mockCacheService },
        { provide: AuditLogService, useValue: auditLog },
      ],
    }).compile();

    service = module.get<VendorSecurityDepositService>(VendorSecurityDepositService);

    // Mock Razorpay SDK client methods so tests don't make network calls
    (service as any).razorpay = {
      orders: {
        create: jest.fn(async ({ amount, currency, receipt, notes }) => ({
          id: `order_rzp_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          entity: 'order',
          amount,
          currency,
          receipt,
          status: 'created',
          notes,
        })),
      },
      payments: {
        fetch: jest.fn(async (paymentId: string) => {
          let orderId = undefined;
          for (const d of deposits.values()) {
            if (d.providerOrderId) {
              orderId = d.providerOrderId;
              break;
            }
          }
          return {
            id: paymentId,
            entity: 'payment',
            amount: 2500000,
            currency: 'INR',
            status: 'captured',
            order_id: orderId,
          };
        }),
      },
    };
  });

  describe('1. Centralized Deposit Policy Configuration', () => {
    it('should bootstrap default policy (₹25,000, 100% refundable) when database is empty', async () => {
      const policy = await service.getActivePolicy();
      expect(policy).toBeDefined();
      expect(policy.version).toBe(1);
      expect(policy.amount).toBe(25000);
      expect(policy.isRequired).toBe(true);
      expect(policy.refundPolicy).toBe('REFUNDABLE');
      expect(policy.currency).toBe('INR');
      expect(policy.paymentProvider).toBe('RAZORPAY');
      expect(policy.isActive).toBe(true);
    });

    it('should allow Super Admin to update policy and publish new version', async () => {
      await service.getActivePolicy(); // bootstrap v1

      const updated = await service.updatePolicy(
        {
          isRequired: true,
          amount: 30000,
          currency: 'INR',
          refundPolicy: 'PARTIALLY_REFUNDABLE',
          description: 'Updated 2026 Security Policy for DriveGo Commercial Partners',
          deadlineDays: 21,
        },
        'admin_super_01',
      );

      expect(updated.version).toBe(2);
      expect(updated.amount).toBe(30000);
      expect(updated.refundPolicy).toBe('PARTIALLY_REFUNDABLE');
      expect(updated.deadlineDays).toBe(21);
      expect(updated.isActive).toBe(true);

      // Verify v1 is deactivated
      const v1 = policies.find((p) => p.version === 1);
      expect(v1.isActive).toBe(false);

      // Verify audit logging
      expect(auditLog.log).toHaveBeenCalledWith(
        'admin_super_01',
        'UPDATE_VENDOR_DEPOSIT_POLICY',
        'VENDOR_DEPOSIT_POLICY',
        expect.any(String),
        expect.objectContaining({
          version: 2,
          amount: 30000,
        }),
      );
    });

    it('should reject invalid or negative deposit amount', async () => {
      await expect(
        service.updatePolicy(
          {
            isRequired: true,
            amount: -500,
            refundPolicy: 'REFUNDABLE',
          },
          'admin_01',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('2. Vendor Deposit Lifecycle & Razorpay Order Creation', () => {
    it('should create a Razorpay payment order for eligible pending vendor', async () => {
      const order = await service.createDepositPaymentOrder('vendor_101', 'usr_101');

      expect(order).toBeDefined();
      expect(order.orderId).toBeDefined();
      expect(order.amount).toBe(2500000); // 25,000 INR in paise
      expect(order.amountInINR).toBe(25000);
      expect(order.currency).toBe('INR');
      expect(order.purpose).toBe('VENDOR_SECURITY_DEPOSIT');
      expect(order.vendor.contactName).toBe('Arjun Verma');

      // Check deposit status updated to PAYMENT_INITIATED
      const dep = deposits.get('vendor_101');
      expect(dep.status).toBe(VendorDepositStatus.PAYMENT_INITIATED);
      expect(dep.providerOrderId).toBe(order.orderId);
      expect(dep.provider).toBe('RAZORPAY');
    });

    it('should prevent order creation if deposit is already PAID', async () => {
      // Mark deposit as paid
      deposits.set('vendor_101', {
        id: 'dep_paid_1',
        vendorId: 'vendor_101',
        requiredAmount: 25000,
        paidAmount: 25000,
        remainingAmount: 0,
        status: VendorDepositStatus.PAID,
      });

      await expect(
        service.createDepositPaymentOrder('vendor_101', 'usr_101'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should prevent order creation if partner is exempt', async () => {
      deposits.set('vendor_101', {
        id: 'dep_exempt_1',
        vendorId: 'vendor_101',
        requiredAmount: 25000,
        paidAmount: 0,
        remainingAmount: 25000,
        status: VendorDepositStatus.NOT_REQUIRED,
        isExempt: true,
      });

      await expect(
        service.createDepositPaymentOrder('vendor_101', 'usr_101'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('3. Payment Verification, HMAC Cryptography & Ledger Integrity', () => {
    it('should verify legitimate HMAC-SHA256 signature and credit deposit', async () => {
      // Initialize deposit
      await service.createDepositPaymentOrder('vendor_101', 'usr_101');
      const dep = deposits.get('vendor_101');

      const testOrderId = dep.providerOrderId;
      const testPaymentId = 'pay_test_razorpay_998877';

      // Generate authentic HMAC-SHA256 signature
      const validSignature = crypto
        .createHmac('sha256', MOCK_KEY_SECRET)
        .update(`${testOrderId}|${testPaymentId}`)
        .digest('hex');

      const result = await service.verifyDepositPayment(
        'vendor_101',
        {
          razorpayOrderId: testOrderId,
          razorpayPaymentId: testPaymentId,
          razorpaySignature: validSignature,
        },
        'usr_101',
      );

      expect(result.success).toBe(true);
      expect(result.deposit.status).toBe(VendorDepositStatus.PAID);
      expect(result.deposit.paidAmount).toBe(25000);
      expect(result.deposit.remainingAmount).toBe(0);

      // Verify audit ledger entry
      expect(result.ledgerEntry).toBeDefined();
      expect(result.ledgerEntry.amount).toBe(25000);
      expect(result.ledgerEntry.direction).toBe('CREDIT');
      expect(result.ledgerEntry.reference).toBe(testPaymentId);
      expect(result.ledgerEntry.paymentMethod).toBe('RAZORPAY_GATEWAY');

      // Verify DEP_SECURITY requirement state marked APPROVED
      const reqState = requirementStates.get('vendor_101_req_def_sec_dep');
      expect(reqState).toBeDefined();
      expect(reqState.status).toBe(RequirementFulfillmentStatus.APPROVED);
    });

    it('should reject tampered or counterfeit signature and set status to PAYMENT_FAILED', async () => {
      await service.createDepositPaymentOrder('vendor_101', 'usr_101');
      const dep = deposits.get('vendor_101');

      await expect(
        service.verifyDepositPayment(
          'vendor_101',
          {
            razorpayOrderId: dep.providerOrderId,
            razorpayPaymentId: 'pay_tampered_123',
            razorpaySignature: 'forged_fake_signature_abc',
          },
          'usr_101',
        ),
      ).rejects.toThrow(BadRequestException);

      expect(dep.status).toBe(VendorDepositStatus.PAYMENT_FAILED);
    });

    it('should handle idempotent re-verification without duplicate billing or ledger entries', async () => {
      await service.createDepositPaymentOrder('vendor_101', 'usr_101');
      const dep = deposits.get('vendor_101');
      const testOrderId = dep.providerOrderId;
      const testPaymentId = 'pay_replay_test_5544';

      const validSignature = crypto
        .createHmac('sha256', MOCK_KEY_SECRET)
        .update(`${testOrderId}|${testPaymentId}`)
        .digest('hex');

      // First verification
      await service.verifyDepositPayment(
        'vendor_101',
        {
          razorpayOrderId: testOrderId,
          razorpayPaymentId: testPaymentId,
          razorpaySignature: validSignature,
        },
        'usr_101',
      );

      const initialLedgerCount = ledgerEntries.length;

      // Replay attempt with same payment ID
      const replayResult = await service.verifyDepositPayment(
        'vendor_101',
        {
          razorpayOrderId: testOrderId,
          razorpayPaymentId: testPaymentId,
          razorpaySignature: validSignature,
        },
        'usr_101',
      );

      expect(replayResult.isReplay).toBe(true);
      expect(replayResult.success).toBe(true);
      expect(ledgerEntries.length).toBe(initialLedgerCount); // No duplicate ledger entry
    });
  });

  describe('4. Super Admin Partner Exemption Workflows', () => {
    it('should allow Super Admin to grant deposit exemption and waive requirement', async () => {
      const exempted = await service.setVendorExemption(
        'vendor_101',
        {
          isExempt: true,
          reason: 'Strategic enterprise partner waiver approved by VP of Operations',
        },
        'admin_super_01',
      );

      expect(exempted.isExempt).toBe(true);
      expect(exempted.status).toBe(VendorDepositStatus.NOT_REQUIRED);
      expect(exempted.exemptionReason).toBe(
        'Strategic enterprise partner waiver approved by VP of Operations',
      );

      // Verify requirement state WAIVED
      const reqState = requirementStates.get('vendor_101_req_def_sec_dep');
      expect(reqState).toBeDefined();
      expect(reqState.status).toBe(RequirementFulfillmentStatus.WAIVED);

      // Verify summary reflects satisfaction
      const summary = await service.getDepositSummary('vendor_101');
      expect(summary.isSatisfied).toBe(true);
      expect(summary.isExempt).toBe(true);
    });

    it('should allow Super Admin to revoke exemption and restore requirement', async () => {
      // First exempt
      await service.setVendorExemption(
        'vendor_101',
        { isExempt: true, reason: 'Temporary waiver' },
        'admin_super_01',
      );

      // Then revoke
      const revoked = await service.setVendorExemption(
        'vendor_101',
        { isExempt: false, reason: 'Waiver expired' },
        'admin_super_01',
      );

      expect(revoked.isExempt).toBe(false);
      expect(revoked.status).toBe(VendorDepositStatus.REQUIRED);

      // Verify requirement state reverted to PENDING
      const reqState = requirementStates.get('vendor_101_req_def_sec_dep');
      expect(reqState.status).toBe(RequirementFulfillmentStatus.PENDING);
    });
  });
});
