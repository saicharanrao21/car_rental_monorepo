import { Test, TestingModule } from '@nestjs/testing';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppController } from './whatsapp.controller';
import { AdminWhatsAppController } from './admin-whatsapp.controller';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { ConfigService } from '@nestjs/config';
import {
  WhatsAppProvider,
  MockWhatsAppProvider,
} from './whatsapp-provider.service';
import {
  WhatsAppMessageStatus,
  WhatsAppMessageType,
} from '@prisma/client';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('Feature 30 — WhatsApp Business Integration Spec', () => {
  let service: WhatsAppService;
  let controller: WhatsAppController;
  let adminController: AdminWhatsAppController;
  let prisma: PrismaService;
  let mockProvider: MockWhatsAppProvider;
  let auditLogService: AuditLogService;

  const mockPrismaService = {
    whatsAppMessage: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
    },
  };

  const mockAuditLogService = {
    log: jest.fn(),
  };

  const mockConfigService = {
    get: jest.fn((key: string) => {
      if (key === 'WHATSAPP_WEBHOOK_VERIFY_TOKEN') return 'test_verify_token';
      if (key === 'WHATSAPP_APP_SECRET') return 'test_secret';
      return null;
    }),
  };

  beforeEach(async () => {
    mockProvider = new MockWhatsAppProvider();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [WhatsAppController, AdminWhatsAppController],
      providers: [
        WhatsAppService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: AuditLogService, useValue: mockAuditLogService },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: WhatsAppProvider, useValue: mockProvider },
      ],
    }).compile();

    service = module.get<WhatsAppService>(WhatsAppService);
    controller = module.get<WhatsAppController>(WhatsAppController);
    adminController = module.get<AdminWhatsAppController>(AdminWhatsAppController);
    prisma = module.get<PrismaService>(PrismaService);
    auditLogService = module.get<AuditLogService>(AuditLogService);

    jest.clearAllMocks();
  });

  describe('1. Phone Number Normalization', () => {
    it('should normalize standard 10-digit Indian phone number to +91', () => {
      expect(service.normalizePhoneNumber('9876543210')).toBe('+919876543210');
      expect(service.normalizePhoneNumber(' 98765 43210 ')).toBe('+919876543210');
    });

    it('should normalize 12-digit Indian number starting with 91', () => {
      expect(service.normalizePhoneNumber('919876543210')).toBe('+919876543210');
      expect(service.normalizePhoneNumber('+919876543210')).toBe('+919876543210');
    });

    it('should throw BadRequestException on invalid phone format', () => {
      expect(() => service.normalizePhoneNumber('')).toThrow(BadRequestException);
      expect(() => service.normalizePhoneNumber('123')).toThrow(BadRequestException);
      expect(() => service.normalizePhoneNumber('abcd')).toThrow(BadRequestException);
    });
  });

  describe('2. Template Parameter Mapping', () => {
    it('should map booking_confirmed variables to positional body params', () => {
      const params = service.getTemplateParameters('booking_confirmed', {
        customerName: 'Sai Charan',
        bookingId: 'bkg_123',
        carName: 'Mahindra Thar',
        pickupDate: '18 Aug 2026',
        pickupLocation: 'Airport Hub',
        totalFare: 5500,
      });

      expect(params).toEqual([
        'Sai Charan',
        'bkg_123',
        'Mahindra Thar',
        '18 Aug 2026',
        'Airport Hub',
        '₹5500',
      ]);
    });

    it('should map payment_successful variables correctly', () => {
      const params = service.getTemplateParameters('payment_successful', {
        customerName: 'Priya',
        bookingId: 'bkg_456',
        amount: 2500,
        paymentId: 'pay_789',
      });

      expect(params).toEqual(['Priya', 'bkg_456', '₹2500', 'pay_789']);
    });
  });

  describe('3. Idempotent Message Dispatch', () => {
    it('should return existing record without resending when idempotencyKey matches', async () => {
      const existingMessage = {
        id: 'msg_existing_1',
        phoneNumber: '+919876543210',
        templateName: 'booking_confirmed',
        status: WhatsAppMessageStatus.SENT,
        idempotencyKey: 'whatsapp_booking_confirmed_bkg_100',
      };

      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValue(existingMessage);
      const sendSpy = jest.spyOn(mockProvider, 'sendMessage');

      const result = await service.sendTemplateMessage({
        phoneNumber: '9876543210',
        messageType: WhatsAppMessageType.BOOKING_CONFIRMED,
        templateName: 'booking_confirmed',
        variables: { customerName: 'Sai' },
        idempotencyKey: 'whatsapp_booking_confirmed_bkg_100',
      });

      expect(result).toBe(existingMessage);
      expect(sendSpy).not.toHaveBeenCalled();
    });

    it('should create new record and send via provider when idempotencyKey is fresh', async () => {
      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValue(null);
      mockPrismaService.whatsAppMessage.create.mockResolvedValue({
        id: 'msg_new_1',
        phoneNumber: '+919876543210',
        status: WhatsAppMessageStatus.QUEUED,
      });
      mockPrismaService.whatsAppMessage.update.mockResolvedValue({
        id: 'msg_new_1',
        phoneNumber: '+919876543210',
        status: WhatsAppMessageStatus.SENT,
        providerMessageId: 'wamid.mock_12345',
      });

      const sendSpy = jest.spyOn(mockProvider, 'sendMessage');

      const result = await service.sendBookingConfirmed({
        id: 'bkg_new_200',
        customerId: 'usr_1',
        customerPhone: '9876543210',
        customerName: 'Sai Charan',
        carName: 'Creta',
        pickupDate: '20 Aug 2026',
        pickupLocation: 'Hitec City',
        totalFare: 3000,
      });

      expect(sendSpy).toHaveBeenCalledWith(
        '+919876543210',
        'booking_confirmed',
        'en_US',
        expect.any(Array),
      );
      expect(result.status).toBe(WhatsAppMessageStatus.SENT);
    });
  });

  describe('4. Meta Webhook Verification & Processing', () => {
    it('should verify Meta webhook challenge with correct token', () => {
      const challenge = controller.verifyWebhook(
        'subscribe',
        'test_verify_token',
        'challenge_code_999',
      );
      expect(challenge).toBe('challenge_code_999');
    });

    it('should throw ForbiddenException on invalid webhook verify token', () => {
      expect(() =>
        controller.verifyWebhook('subscribe', 'wrong_token', 'challenge_code'),
      ).toThrow(ForbiddenException);
    });

    it('should transition status monotonically: QUEUED/SENT -> DELIVERED -> READ', async () => {
      // 1. Ingest 'delivered' receipt
      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValueOnce({
        id: 'msg_track_1',
        status: WhatsAppMessageStatus.SENT,
      });

      const webhookDeliveredPayload = {
        object: 'whatsapp_business_account',
        entry: [
          {
            id: 'entry_1',
            changes: [
              {
                value: {
                  statuses: [
                    {
                      id: 'wamid.123',
                      status: 'delivered' as const,
                      timestamp: '1723890000',
                      recipient_id: '919876543210',
                    },
                  ],
                },
              },
            ],
          },
        ],
      };

      const res1 = await service.handleWebhookEvent(webhookDeliveredPayload);
      expect(res1.processed).toBe(1);
      expect(mockPrismaService.whatsAppMessage.update).toHaveBeenCalledWith({
        where: { id: 'msg_track_1' },
        data: expect.objectContaining({
          status: WhatsAppMessageStatus.DELIVERED,
        }),
      });

      // 2. Ingest 'read' receipt
      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValueOnce({
        id: 'msg_track_1',
        status: WhatsAppMessageStatus.DELIVERED,
      });

      const webhookReadPayload = {
        object: 'whatsapp_business_account',
        entry: [
          {
            id: 'entry_1',
            changes: [
              {
                value: {
                  statuses: [
                    {
                      id: 'wamid.123',
                      status: 'read' as const,
                      timestamp: '1723890100',
                      recipient_id: '919876543210',
                    },
                  ],
                },
              },
            ],
          },
        ],
      };

      const res2 = await service.handleWebhookEvent(webhookReadPayload);
      expect(res2.processed).toBe(1);
      expect(mockPrismaService.whatsAppMessage.update).toHaveBeenCalledWith({
        where: { id: 'msg_track_1' },
        data: expect.objectContaining({
          status: WhatsAppMessageStatus.READ,
        }),
      });
    });

    it('should not downgrade status from DELIVERED back to SENT', async () => {
      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValueOnce({
        id: 'msg_track_1',
        status: WhatsAppMessageStatus.DELIVERED,
      });

      const duplicateSentPayload = {
        object: 'whatsapp_business_account',
        entry: [
          {
            id: 'entry_1',
            changes: [
              {
                value: {
                  statuses: [
                    {
                      id: 'wamid.123',
                      status: 'delivered' as const, // already delivered
                      timestamp: '1723890000',
                      recipient_id: '919876543210',
                    },
                  ],
                },
              },
            ],
          },
        ],
      };

      const res = await service.handleWebhookEvent(duplicateSentPayload);
      expect(res.processed).toBe(0);
    });
  });

  describe('5. Admin Analytics & Resend Operations', () => {
    it('should aggregate summary counts and delivery rate percentage', async () => {
      mockPrismaService.whatsAppMessage.count
        .mockResolvedValueOnce(10) // total
        .mockResolvedValueOnce(2) // sent
        .mockResolvedValueOnce(5) // delivered
        .mockResolvedValueOnce(2) // read
        .mockResolvedValueOnce(1); // failed

      const summary = await service.getSummary();

      expect(summary.totalMessages).toBe(10);
      expect(summary.sentCount).toBe(2);
      expect(summary.deliveredCount).toBe(5);
      expect(summary.readCount).toBe(2);
      expect(summary.failedCount).toBe(1);
      expect(summary.deliveryRatePercent).toBe(70.0); // (5+2)/10 = 70%
    });

    it('should allow admin to resend failed message and record in AuditLog', async () => {
      const failedMsg = {
        id: 'msg_failed_1',
        phoneNumber: '+919876543210',
        templateName: 'booking_confirmed',
        templateLanguage: 'en_US',
        variables: { customerName: 'Sai' },
        status: WhatsAppMessageStatus.FAILED,
      };

      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValue(failedMsg);
      mockPrismaService.whatsAppMessage.update.mockResolvedValue({
        ...failedMsg,
        status: WhatsAppMessageStatus.SENT,
      });

      const result = await service.resendMessage('msg_failed_1', 'admin_user_1');

      expect(result.status).toBe(WhatsAppMessageStatus.SENT);
      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        'admin_user_1',
        'WHATSAPP_MANUAL_RESEND',
        'WhatsAppMessage',
        'msg_failed_1',
        expect.any(Object),
      );
    });

    it('should throw NotFoundException on resending non-existent message ID', async () => {
      mockPrismaService.whatsAppMessage.findUnique.mockResolvedValue(null);

      await expect(
        service.resendMessage('msg_nonexistent', 'admin_1'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
