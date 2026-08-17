import { Test, TestingModule } from '@nestjs/testing';
import { FraudService, RiskLevel, RiskAction } from './fraud.service';
import { PrismaService } from '../prisma/prisma.service';
import { AdminFraudController } from './admin-fraud.controller';
import { NotFoundException } from '@nestjs/common';
import { BookingStatus, PaymentStatus } from '@prisma/client';
import { RiskResolutionStatus } from './dto/resolve-risk-assessment.dto';

describe('Feature 34 — Fraud Detection & Risk Scoring Spec', () => {
  let service: FraudService;
  let controller: AdminFraudController;
  let prisma: PrismaService;

  const mockPrismaService = {
    user: {
      findUnique: jest.fn(),
    },
    customerKyc: {
      count: jest.fn(),
    },
    booking: {
      count: jest.fn(),
    },
    payment: {
      count: jest.fn(),
    },
    auditLog: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AdminFraudController],
      providers: [
        FraudService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<FraudService>(FraudService);
    controller = module.get<AdminFraudController>(AdminFraudController);
    prisma = module.get<PrismaService>(PrismaService);

    jest.clearAllMocks();
  });

  describe('1. Deterministic Risk Scoring & Thresholds', () => {
    it('should assign LOW risk and ALLOW action for clean user with zero signals', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_clean',
        name: 'Clean User',
        phone: '+919876543210',
        banned: false,
        createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days old
        customerKyc: { licenceNumber: 'DL-KA-01-2022-001' },
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      mockPrismaService.booking.count.mockResolvedValue(0);
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_clean');

      expect(result.score).toBe(0);
      expect(result.riskLevel).toBe(RiskLevel.LOW);
      expect(result.action).toBe(RiskAction.ALLOW);
      expect(result.signals).toHaveLength(0);
      expect(mockPrismaService.auditLog.create).not.toHaveBeenCalled();
    });

    it('should assign MEDIUM risk and MONITOR action when score is between 30 and 59', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_med',
        name: 'Medium Risk User',
        phone: '+919876543211',
        banned: false,
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        customerKyc: null,
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      // High cancellation velocity gives +30
      mockPrismaService.booking.count.mockImplementation((args: any) => {
        if (args?.where?.status === BookingStatus.CANCELLED) return 3;
        return 0;
      });
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_med');

      expect(result.score).toBe(30);
      expect(result.riskLevel).toBe(RiskLevel.MEDIUM);
      expect(result.action).toBe(RiskAction.MONITOR);
      expect(result.signals).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ code: 'HIGH_CANCELLATION_VELOCITY', scoreDelta: 30 }),
        ]),
      );
    });

    it('should assign HIGH risk and REVIEW_REQUIRED action when score is between 60 and 79', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_high',
        name: 'High Risk User',
        phone: '+919876543212',
        banned: false,
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        customerKyc: { licenceNumber: 'DL-TS-09-2023-999' },
      });
      // Duplicate DL gives +40
      mockPrismaService.customerKyc.count.mockResolvedValue(1);
      // High booking velocity gives +25 (Total = 65)
      mockPrismaService.booking.count.mockImplementation((args: any) => {
        if (args?.where?.createdAt) return 3;
        return 0;
      });
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_high');

      expect(result.score).toBe(65);
      expect(result.riskLevel).toBe(RiskLevel.HIGH);
      expect(result.action).toBe(RiskAction.REVIEW_REQUIRED);
      expect(result.signals).toHaveLength(2);
      expect(mockPrismaService.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            action: 'RISK_ASSESSMENT_ALERT',
            targetId: 'usr_high',
          }),
        }),
      );
    });

    it('should assign CRITICAL risk and BLOCK action when score >= 80 or user is banned', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_banned',
        name: 'Banned Fraudster',
        phone: '+919876543213',
        banned: true, // +100 score
        createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000),
        customerKyc: null,
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      mockPrismaService.booking.count.mockResolvedValue(0);
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_banned');

      expect(result.score).toBe(100);
      expect(result.riskLevel).toBe(RiskLevel.CRITICAL);
      expect(result.action).toBe(RiskAction.BLOCK);
      expect(result.signals).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ code: 'BANNED_USER', scoreDelta: 100 }),
        ]),
      );
    });
  });

  describe('2. Specific Risk Signals & Explainability', () => {
    it('should detect duplicate driving licence registered across other user accounts (+40)', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_dup_dl',
        name: 'Syndicate Member',
        phone: '+919876543214',
        banned: false,
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        customerKyc: { licenceNumber: 'DL-MH-02-2020-5555' },
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(2); // found on 2 other accounts
      mockPrismaService.booking.count.mockResolvedValue(0);
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_dup_dl');

      const dlSignal = result.signals.find((s) => s.code === 'DUPLICATE_DRIVING_LICENCE');
      expect(dlSignal).toBeDefined();
      expect(dlSignal?.scoreDelta).toBe(40);
      expect(dlSignal?.description).toContain('registered on 2 other user account(s)');
    });

    it('should detect repeated payment failures in the last 24 hours (+35)', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_pay_fail',
        name: 'Card Tester',
        phone: '+919876543215',
        banned: false,
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        customerKyc: null,
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      mockPrismaService.booking.count.mockResolvedValue(0);
      mockPrismaService.payment.count.mockResolvedValue(4); // 4 payment failures

      const result = await service.evaluateUserRisk('usr_pay_fail');

      const paySignal = result.signals.find((s) => s.code === 'REPEATED_PAYMENT_FAILURES');
      expect(paySignal).toBeDefined();
      expect(paySignal?.scoreDelta).toBe(35);
      expect(paySignal?.description).toContain('4 failed payment attempts');
    });

    it('should detect multiple concurrent active trips (+20)', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_concurrent',
        name: 'Fleet Stretcher',
        phone: '+919876543216',
        banned: false,
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
        customerKyc: null,
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      mockPrismaService.booking.count.mockImplementation((args: any) => {
        if (args?.where?.status?.in) return 2; // 2 ongoing bookings
        return 0;
      });
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_concurrent');

      const activeSignal = result.signals.find((s) => s.code === 'MULTIPLE_ACTIVE_BOOKINGS');
      expect(activeSignal).toBeDefined();
      expect(activeSignal?.scoreDelta).toBe(20);
    });

    it('should detect fresh account high activity spike (+15)', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue({
        id: 'usr_fresh',
        name: 'Brand New User',
        phone: '+919876543217',
        banned: false,
        createdAt: new Date(Date.now() - 15 * 60 * 1000), // 15 mins old
        customerKyc: null,
      });
      mockPrismaService.customerKyc.count.mockResolvedValue(0);
      mockPrismaService.booking.count.mockImplementation((args: any) => {
        if (args?.where?.createdAt) return 2; // 2 bookings in 2h
        return 0;
      });
      mockPrismaService.payment.count.mockResolvedValue(0);

      const result = await service.evaluateUserRisk('usr_fresh');

      const freshSignal = result.signals.find((s) => s.code === 'FRESH_ACCOUNT_SPIKE');
      expect(freshSignal).toBeDefined();
      expect(freshSignal?.scoreDelta).toBe(15);
    });

    it('should throw NotFoundException when evaluating non-existent user ID', async () => {
      mockPrismaService.user.findUnique.mockResolvedValue(null);

      await expect(service.evaluateUserRisk('usr_missing')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('3. Fraud Summary & Assessment Management', () => {
    it('should aggregate summary counts by risk level correctly', async () => {
      mockPrismaService.auditLog.findMany.mockResolvedValue([
        { metadata: { riskLevel: RiskLevel.CRITICAL, status: 'PENDING_REVIEW' } },
        { metadata: { riskLevel: RiskLevel.CRITICAL, status: 'RESOLVED' } },
        { metadata: { riskLevel: RiskLevel.HIGH, status: 'PENDING_REVIEW' } },
        { metadata: { riskLevel: RiskLevel.MEDIUM, status: 'DISMISSED' } },
        { metadata: { riskLevel: RiskLevel.LOW, status: 'RESOLVED' } },
      ]);

      const summary = await service.getFraudSummary();

      expect(summary.totalEvents).toBe(5);
      expect(summary.criticalCount).toBe(2);
      expect(summary.highCount).toBe(1);
      expect(summary.mediumCount).toBe(1);
      expect(summary.lowCount).toBe(1);
      expect(summary.pendingReviewCount).toBe(2);
    });

    it('should retrieve paginated risk assessments with filters', async () => {
      mockPrismaService.auditLog.count.mockResolvedValue(1);
      mockPrismaService.auditLog.findMany.mockResolvedValue([
        {
          id: 'log_risk_1',
          targetId: 'usr_high',
          createdAt: new Date(),
          metadata: {
            userName: 'High Risk User',
            userPhone: '+919876543212',
            score: 65,
            riskLevel: RiskLevel.HIGH,
            action: RiskAction.REVIEW_REQUIRED,
            signals: [{ code: 'DUPLICATE_DRIVING_LICENCE', scoreDelta: 40 }],
            status: 'PENDING_REVIEW',
          },
        },
      ]);

      const result = await service.getRiskAssessments({ riskLevel: 'HIGH', page: 1, limit: 10 });

      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('log_risk_1');
      expect(result.data[0].score).toBe(65);
      expect(result.data[0].riskLevel).toBe(RiskLevel.HIGH);
      expect(result.total).toBe(1);
    });

    it('should resolve risk assessment and write administrative resolution audit log', async () => {
      mockPrismaService.auditLog.findUnique.mockResolvedValue({
        id: 'log_risk_1',
        action: 'RISK_ASSESSMENT_ALERT',
        metadata: {
          status: 'PENDING_REVIEW',
          score: 65,
        },
      });
      mockPrismaService.auditLog.update.mockResolvedValue({});
      mockPrismaService.auditLog.create.mockResolvedValue({});

      const response = await service.resolveRiskAssessment('admin_001', 'log_risk_1', {
        status: RiskResolutionStatus.RESOLVED,
        adminNotes: 'Customer verified in person with original documents.',
      });

      expect(response.success).toBe(true);
      expect(response.status).toBe(RiskResolutionStatus.RESOLVED);
      expect(mockPrismaService.auditLog.update).toHaveBeenCalledWith({
        where: { id: 'log_risk_1' },
        data: expect.objectContaining({
          metadata: expect.objectContaining({
            status: RiskResolutionStatus.RESOLVED,
            resolvedBy: 'admin_001',
          }),
        }),
      });
      expect(mockPrismaService.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            action: 'FRAUD_RISK_RESOLUTION',
            adminUserId: 'admin_001',
          }),
        }),
      );
    });

    it('should throw NotFoundException when resolving non-existent assessment', async () => {
      mockPrismaService.auditLog.findUnique.mockResolvedValue(null);

      await expect(
        service.resolveRiskAssessment('admin_001', 'log_invalid', {
          status: RiskResolutionStatus.DISMISSED,
          adminNotes: 'Dismissing false alarm.',
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('4. Admin Controller Routes', () => {
    it('controller getSummary should call service.getFraudSummary', async () => {
      jest.spyOn(service, 'getFraudSummary').mockResolvedValue({
        totalEvents: 10,
        criticalCount: 2,
        highCount: 3,
        mediumCount: 4,
        lowCount: 1,
        pendingReviewCount: 5,
      });

      const res = await controller.getSummary();
      expect(res.totalEvents).toBe(10);
      expect(res.criticalCount).toBe(2);
    });

    it('controller getUserRiskProfile should return evaluated risk profile', async () => {
      jest.spyOn(service, 'evaluateUserRisk').mockResolvedValue({
        userId: 'usr_test',
        userName: 'Test User',
        userPhone: '+919999999999',
        score: 0,
        riskLevel: RiskLevel.LOW,
        action: RiskAction.ALLOW,
        signals: [],
        evaluatedAt: new Date(),
      });

      const res = await controller.getUserRiskProfile('usr_test');
      expect(res.userId).toBe('usr_test');
      expect(res.riskLevel).toBe(RiskLevel.LOW);
    });
  });
});
