import { NotificationsService } from './notifications.service';
import { FcmService } from './fcm.service';
import { AuditLogService } from '../admin/audit-log.service';

describe('NotificationsOrchestrator (Phase 27.5)', () => {
  let service: NotificationsService;
  let mockPrisma: any;
  let mockFcm: any;
  let mockAudit: any;
  let mockQueueProducer: any;
  let mockSystemConfig: any;

  beforeEach(() => {
    mockPrisma = {
      notification: {
        findUnique: jest.fn(),
        create: jest.fn(),
        createMany: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        deleteMany: jest.fn().mockResolvedValue({ count: 5 }),
      },
      userDevice: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      notificationPreference: {
        findUnique: jest.fn(),
        create: jest.fn(),
        upsert: jest.fn(),
      },
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };

    mockFcm = {
      sendToUser: jest.fn().mockResolvedValue(undefined),
      sendMulticast: jest.fn().mockResolvedValue(undefined),
    };

    mockAudit = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockQueueProducer = {
      dispatchSmsNotification: jest.fn().mockResolvedValue(undefined),
      dispatchEmailNotification: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfig = {
      getNotificationConfig: jest.fn().mockResolvedValue({
        enableFcmPush: true,
        enableSmsNotifications: true,
        enableEmailNotifications: true,
        enableWhatsAppNotifications: true,
        maxBatchMulticastSize: 500,
        retentionDaysTransactional: 365,
        retentionDaysMarketing: 30,
      }),
    };

    service = new NotificationsService(
      mockPrisma,
      mockFcm as any,
      mockAudit,
      mockQueueProducer,
      mockSystemConfig,
    );
  });

  describe('Deduplication & Idempotency', () => {
    it('should return existing notification without creating duplicate or re-dispatching when idempotencyKey matches', async () => {
      const existingNotif = {
        id: 'notif-1',
        userId: 'u1',
        title: 'Booking Confirmed',
        body: 'Trip starts tomorrow',
        idempotencyKey: 'evt_booking_123_CONFIRMED',
      };

      mockPrisma.notification.findUnique.mockResolvedValue(existingNotif);

      const result = await service.sendNotification({
        userId: 'u1',
        title: 'Booking Confirmed',
        body: 'Trip starts tomorrow',
        idempotencyKey: 'evt_booking_123_CONFIRMED',
      });

      expect(result).toBe(existingNotif);
      expect(mockPrisma.notification.create).not.toHaveBeenCalled();
      expect(mockFcm.sendToUser).not.toHaveBeenCalled();
    });
  });

  describe('Notification Preferences & Channel Governance', () => {
    it('should enforce promotional push opt-out while allowing mandatory transactional push', async () => {
      // User opted OUT of promotional push
      mockPrisma.notificationPreference.findUnique.mockResolvedValue({
        userId: 'u1',
        promotionalPush: false,
        operationalPush: true,
        promotionalSms: false,
        operationalSms: true,
        promotionalEmail: false,
        operationalEmail: true,
      });

      mockPrisma.notification.findUnique.mockResolvedValue(null);
      mockPrisma.notification.create.mockImplementation((args: any) => ({
        id: 'notif-promo',
        ...args.data,
      }));
      mockPrisma.userDevice.findMany.mockResolvedValue([{ token: 'tok-1' }]);

      // 1. Promotional notification (should NOT push)
      await service.sendNotification({
        userId: 'u1',
        title: 'Weekend 20% Off',
        body: 'Rent now and save',
        category: 'GROWTH',
        isTransactional: false,
      });

      expect(mockFcm.sendToUser).not.toHaveBeenCalled();

      // 2. Transactional notification (MUST push regardless of promo settings)
      await service.sendNotification({
        userId: 'u1',
        title: 'Payment Successful',
        body: '₹5,000 paid for trip',
        category: 'PAYMENT',
        isTransactional: true,
      });

      expect(mockFcm.sendToUser).toHaveBeenCalledWith('u1', 'Payment Successful', '₹5,000 paid for trip');
    });
  });

  describe('Multi-Device Token Registration', () => {
    it('should register and update active device session', async () => {
      mockPrisma.userDevice.findUnique.mockResolvedValue(null);
      mockPrisma.userDevice.create.mockImplementation((args: any) => ({
        id: 'dev-1',
        ...args.data,
      }));

      const dev = await service.registerDevice('u1', {
        token: 'fcm_token_xyz_123',
        platform: 'ANDROID',
        deviceId: 'pixel_9_pro',
      });

      expect(dev.token).toBe('fcm_token_xyz_123');
      expect(mockPrisma.userDevice.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'u1',
            token: 'fcm_token_xyz_123',
            platform: 'ANDROID',
          }),
        }),
      );
    });

    it('should safely unregister device on logout', async () => {
      await service.unregisterDevice('u1', 'fcm_token_xyz_123');

      expect(mockPrisma.userDevice.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1', token: 'fcm_token_xyz_123' },
        data: { isActive: false },
      });
    });
  });

  describe('Retention Cleanup', () => {
    it('should clean up old read marketing notifications beyond retention window', async () => {
      const result = await service.cleanupOldNotifications();

      expect(result.deletedMarketingCount).toBe(5);
      expect(mockPrisma.notification.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            category: 'GROWTH',
            isRead: true,
          }),
        }),
      );
    });
  });
});
