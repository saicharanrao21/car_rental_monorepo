import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { NotificationOrchestratorService } from './notification-orchestrator.service';
import { NotificationRealtimeService } from './notification-realtime.service';
import { FcmService } from './fcm.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { DeliveryStatus, NotificationChannel, NotificationPriority } from '@prisma/client';
import { firstValueFrom, take, toArray } from 'rxjs';

describe('Phase 32: Notification & Real-Time Hardening', () => {
  let notificationsService: NotificationsService;
  let realtimeService: NotificationRealtimeService;
  let fcmService: FcmService;
  let mockPrisma: any;
  let mockOrchestrator: any;

  beforeEach(async () => {
    mockPrisma = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      userDevice: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      notification: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        count: jest.fn(),
      },
      notificationPreference: {
        findUnique: jest.fn(),
        create: jest.fn(),
        upsert: jest.fn(),
      },
      notificationDelivery: {
        create: jest.fn(),
        update: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
      },
    };

    mockOrchestrator = {
      publishEvent: jest.fn(),
    };

    realtimeService = new NotificationRealtimeService();

    const mockConfig = { get: jest.fn().mockReturnValue(null) };
    fcmService = new FcmService(mockConfig as any, mockPrisma as any);

    notificationsService = new NotificationsService(
      mockPrisma as any,
      fcmService,
      { log: jest.fn() } as any,
      undefined,
      undefined,
      mockOrchestrator as any,
      realtimeService,
    );
  });

  describe('1. Multi-Device Push & FCM Token Lifecycle', () => {
    it('should fan out push notifications across all active user devices', async () => {
      mockPrisma.userDevice.findMany.mockResolvedValueOnce([
        { token: 'token_pixel_7' },
        { token: 'token_ipad_pro' },
      ]);

      const result = await fcmService.sendToUser(
        'user_multi_device',
        'Handover Ready',
        'Vehicle is prepared for inspection',
      );

      expect(result?.success).toBe(true);
      expect(result?.activeDeviceCount).toBe(2);
      expect(mockPrisma.userDevice.findMany).toHaveBeenCalledWith({
        where: { userId: 'user_multi_device', isActive: true },
        select: { token: true },
      });
    });

    it('should fallback to legacy user.fcmToken if no UserDevice records exist', async () => {
      mockPrisma.userDevice.findMany.mockResolvedValueOnce([]);
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        fcmToken: 'legacy_single_token',
      });

      const result = await fcmService.sendToUser(
        'user_legacy',
        'Booking Confirmed',
        'Trip starts at 10 AM',
      );

      expect(result?.success).toBe(true);
      expect(result?.activeDeviceCount).toBe(1);
    });

    it('should gracefully handle user with no active devices or legacy tokens', async () => {
      mockPrisma.userDevice.findMany.mockResolvedValueOnce([]);
      mockPrisma.user.findUnique.mockResolvedValueOnce({ fcmToken: null });

      const result = await fcmService.sendToUser(
        'user_offline',
        'Payment Captured',
        'Receipt #123',
      );

      expect(result?.success).toBe(true);
      expect(result?.messageId).toBe('no_active_devices');
      expect(result?.activeDeviceCount).toBe(0);
    });

    it('should deactivate superseded tokens when same physical device registers new token', async () => {
      mockPrisma.userDevice.findUnique.mockResolvedValueOnce(null);
      mockPrisma.userDevice.create.mockResolvedValueOnce({
        id: 'dev_new',
        token: 'new_rotated_token',
      });

      await notificationsService.registerDevice('user_123', {
        token: 'new_rotated_token',
        platform: 'ANDROID',
        deviceId: 'hardware_imei_999',
        appVersion: '1.2.0',
      });

      // Deactivate other users on this hardware
      expect(mockPrisma.userDevice.updateMany).toHaveBeenCalledWith({
        where: {
          deviceId: 'hardware_imei_999',
          userId: { not: 'user_123' },
          isActive: true,
        },
        data: { isActive: false },
      });

      // Deactivate old tokens for this user on this hardware
      expect(mockPrisma.userDevice.updateMany).toHaveBeenCalledWith({
        where: {
          deviceId: 'hardware_imei_999',
          userId: 'user_123',
          token: { not: 'new_rotated_token' },
          isActive: true,
        },
        data: { isActive: false },
      });
    });

    it('should query active user devices and revoke by deviceId', async () => {
      mockPrisma.userDevice.findMany.mockResolvedValueOnce([
        { id: 'd1', platform: 'ANDROID', deviceId: 'dev_1', appVersion: '1.0' },
      ]);
      mockPrisma.userDevice.updateMany.mockResolvedValueOnce({ count: 1 });

      const devices = await notificationsService.getUserDevices('u1');
      expect(devices).toHaveLength(1);

      const revokeResult = await notificationsService.revokeDevice('u1', 'dev_1');
      expect(revokeResult.success).toBe(true);
      expect(revokeResult.count).toBe(1);
    });

    it('should bulk deactivate devices inactive for > 90 days', async () => {
      mockPrisma.userDevice.updateMany.mockResolvedValueOnce({ count: 14 });

      const res = await notificationsService.cleanupStaleDevices(90);
      expect(res.cleanedCount).toBe(14);
      expect(mockPrisma.userDevice.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            isActive: true,
            lastSeenAt: expect.any(Object),
          }),
          data: { isActive: false },
        }),
      );
    });
  });

  describe('2. Real-Time Live Stream (SSE)', () => {
    it('should emit live notification and unread count to user event stream', async () => {
      const streamPromise = firstValueFrom(
        realtimeService.getUserStream('usr_sse_target').pipe(take(2), toArray()),
      );

      realtimeService.emitToUser('usr_sse_target', 'notification', {
        id: 'notif_live_1',
        title: 'Booking Approved',
      });
      realtimeService.emitToUser('usr_sse_target', 'unread_count', {
        unreadCount: 4,
      });

      const events = await streamPromise;
      expect(events).toHaveLength(2);
      expect(events[0].data.type).toBe('notification');
      expect(events[0].data.payload.id).toBe('notif_live_1');
      expect(events[1].data.type).toBe('unread_count');
      expect(events[1].data.payload.unreadCount).toBe(4);
    });

    it('should isolate realtime streams across different users', (done) => {
      const targetUser = 'usr_alice';
      const otherUser = 'usr_bob';

      const subscription = realtimeService.getUserStream(targetUser).subscribe({
        next: (msg) => {
          expect(msg.data.payload.id).toBe('msg_for_alice');
          subscription.unsubscribe();
          done();
        },
      });

      // Emit for Bob (should not trigger Alice's subscription)
      realtimeService.emitToUser(otherUser, 'notification', { id: 'msg_for_bob' });
      // Emit for Alice
      realtimeService.emitToUser(targetUser, 'notification', { id: 'msg_for_alice' });
    });
  });

  describe('3. Canonical Business Event Fan-Out Bridge', () => {
    it('should delegate operational domain events to NotificationOrchestratorService', async () => {
      mockOrchestrator.publishEvent.mockResolvedValueOnce({
        id: 'notif_orchestrated_01',
        eventType: 'BOOKING_CONFIRMED',
      });

      const result = await notificationsService.sendNotification({
        userId: 'cust_101',
        title: 'Booking #BK-999 Confirmed',
        body: 'Vehicle ready for pickup',
        eventType: 'BOOKING_CONFIRMED',
        entityType: 'BOOKING',
        entityId: 'BK-999',
        isTransactional: true,
      });

      expect(mockOrchestrator.publishEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: 'BOOKING_CONFIRMED',
          recipientId: 'cust_101',
          entityType: 'BOOKING',
          entityId: 'BK-999',
          isTransactional: true,
        }),
      );
      expect(result.id).toBe('notif_orchestrated_01');
    });
  });

  describe('4. Server-Authoritative Read State & Invariants', () => {
    it('should preserve original readAt timestamp on idempotent duplicate markAsRead calls', async () => {
      const originalReadAt = new Date('2026-09-01T10:00:00.000Z');
      mockPrisma.notification.findUnique.mockResolvedValueOnce({
        id: 'n1',
        userId: 'u1',
        isRead: true,
        readAt: originalReadAt,
      });
      mockPrisma.notification.update.mockResolvedValueOnce({
        id: 'n1',
        isRead: true,
        readAt: originalReadAt,
      });
      mockPrisma.notification.count.mockResolvedValueOnce(0);

      const updated = await notificationsService.markAsRead('u1', 'n1');

      expect(mockPrisma.notification.update).toHaveBeenCalledWith({
        where: { id: 'n1' },
        data: {
          isRead: true,
          readAt: originalReadAt,
        },
      });
      expect(updated.readAt).toEqual(originalReadAt);
    });

    it('should prevent IDOR by throwing NotFoundException when marking another user notification as read', async () => {
      mockPrisma.notification.findUnique.mockResolvedValueOnce({
        id: 'n1',
        userId: 'other_user',
      });

      await expect(
        notificationsService.markAsRead('attacker_user', 'n1'),
      ).rejects.toThrow('Notification not found.');
    });
  });
});
