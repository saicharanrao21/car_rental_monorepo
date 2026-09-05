import {
  Injectable,
  Logger,
  Optional,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FcmService } from './fcm.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto';
import { SendNotificationDto } from './dto/send-notification.dto';
import { Role, Prisma } from '@prisma/client';

import { NotificationOrchestratorService } from './notification-orchestrator.service';
import { NotificationRealtimeService } from './notification-realtime.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcmService: FcmService,
    private readonly auditLogService: AuditLogService,
    @Optional() private readonly queueProducer?: QueueProducerService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
    @Optional() private readonly orchestrator?: NotificationOrchestratorService,
    @Optional() private readonly realtimeService?: NotificationRealtimeService,
  ) {}

  /**
   * Primary notification orchestrator with database idempotency, preference checks, and async channels.
   */
  async sendNotification(dto: SendNotificationDto) {
    const {
      userId,
      title,
      body,
      category = 'GENERAL',
      eventType,
      entityType,
      entityId,
      actionUrl,
      idempotencyKey,
      metadata,
      isTransactional = true,
    } = dto;

    // Bridge with Canonical NotificationOrchestratorService if domain lifecycle event
    if (this.orchestrator && eventType && entityType && entityId) {
      return this.orchestrator.publishEvent({
        eventType,
        recipientId: userId,
        entityType,
        entityId,
        variables: {
          title,
          body,
          ...(typeof metadata === 'object' && metadata ? metadata : {}),
        },
        priority: dto.priority as any,
        isTransactional,
      });
    }

    // 1. Permanent Deduplication Check (Database Uniqueness)
    if (idempotencyKey) {
      const existing = await this.prisma.notification.findUnique({
        where: { idempotencyKey },
      });
      if (existing) {
        this.logger.log(
          `[NOTIF DEDUP] Idempotent notification hit for key: ${idempotencyKey}. Skipping duplicate creation.`,
        );
        return existing;
      }
    }

    // 2. Fetch User Notification Preferences
    const prefs = await this.getPreferences(userId);

    // Determine channel dispatch eligibility based on preferences and transactionality
    const allowPush = isTransactional || prefs.promotionalPush;
    const allowSms = isTransactional ? prefs.operationalSms : prefs.promotionalSms;
    const allowEmail = isTransactional ? prefs.operationalEmail : prefs.promotionalEmail;

    // 3. Create In-App Notification (Synchronous source of truth)
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        title,
        body,
        category,
        eventType,
        entityType,
        entityId,
        actionUrl,
        idempotencyKey,
        metadata: metadata || Prisma.JsonNull,
        isRead: false,
      },
    });

    // Realtime SSE broadcast
    if (this.realtimeService) {
      this.realtimeService.emitToUser(userId, 'notification', notification);
      this.prisma.notification
        .count({ where: { userId, isRead: false } })
        .then((cnt) =>
          this.realtimeService?.emitToUser(userId, 'unread_count', {
            unreadCount: cnt,
          }),
        )
        .catch(() => {});
    }

    // 4. Dispatch Multi-Device Push Notifications (if allowed)
    if (allowPush) {
      this.dispatchPushToUser(userId, title, body, actionUrl).catch((err) =>
        this.logger.warn(`Push dispatch failed for user ${userId}: ${err?.message}`),
      );
    }

    // 5. Asynchronous SMS and Email Delivery via QueueProducer (if allowed)
    if (this.queueProducer) {
      this.dispatchAsyncExternalChannels(userId, title, body, allowSms, allowEmail).catch(
        (err) =>
          this.logger.warn(
            `Async channel dispatch failed for user ${userId}: ${err?.message}`,
          ),
      );
    }

    return notification;
  }

  /**
   * Convenience backward-compatible notification helper.
   */
  async notifyUser(
    userId: string,
    title: string,
    body: string,
    category = 'GENERAL',
    eventType?: string,
    entityType?: string,
    entityId?: string,
    idempotencyKey?: string,
  ) {
    return this.sendNotification({
      userId,
      title,
      body,
      category,
      eventType,
      entityType,
      entityId,
      idempotencyKey,
      isTransactional: true,
    });
  }

  // ── Multi-Device Push Dispatch ────────────────────────────────────────────

  private async dispatchPushToUser(
    userId: string,
    title: string,
    body: string,
    actionUrl?: string,
  ) {
    const activeDevices = await this.prisma.userDevice.findMany({
      where: { userId, isActive: true },
      select: { token: true },
    });

    let tokens = activeDevices.map((d) => d.token);

    // Fallback: check legacy single fcmToken on User
    if (tokens.length === 0) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { fcmToken: true },
      });
      if (user?.fcmToken) {
        tokens = [user.fcmToken];
      }
    }

    if (tokens.length === 1) {
      await this.fcmService.sendToUser(userId, title, body);
    } else if (tokens.length > 1) {
      await this.fcmService.sendMulticast(tokens, title, body);
    }
  }

  private async dispatchAsyncExternalChannels(
    userId: string,
    title: string,
    body: string,
    allowSms: boolean,
    allowEmail: boolean,
  ) {
    if (!allowSms && !allowEmail) return;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true, email: true },
    });

    if (!user) return;

    if (allowSms && user.phone && this.queueProducer) {
      await this.queueProducer.dispatchSmsNotification({
        phone: user.phone,
        message: `${title}: ${body}`,
      });
    }

    if (allowEmail && user.email && this.queueProducer) {
      await this.queueProducer.dispatchEmailNotification({
        to: user.email,
        subject: title,
        htmlContent: `<p>${body}</p>`,
      });
    }
  }

  // ── Device Token Registration & Multi-Device Sessions ─────────────────────

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    // 1. If physical deviceId is provided, clean up stale/conflicting associations
    if (dto.deviceId) {
      // Deactivate any existing device records registered to other users on this same hardware
      await this.prisma.userDevice.updateMany({
        where: {
          deviceId: dto.deviceId,
          userId: { not: userId },
          isActive: true,
        },
        data: { isActive: false },
      });

      // Deactivate previous tokens for this user on this same physical device (token rotation)
      await this.prisma.userDevice.updateMany({
        where: {
          deviceId: dto.deviceId,
          userId,
          token: { not: dto.token },
          isActive: true,
        },
        data: { isActive: false },
      });
    }

    const existing = await this.prisma.userDevice.findUnique({
      where: { token: dto.token },
    });

    let device;
    if (existing) {
      device = await this.prisma.userDevice.update({
        where: { token: dto.token },
        data: {
          userId,
          platform: dto.platform || existing.platform,
          deviceId: dto.deviceId || existing.deviceId,
          appVersion: dto.appVersion || existing.appVersion,
          isActive: true,
          lastSeenAt: new Date(),
        },
      });
    } else {
      device = await this.prisma.userDevice.create({
        data: {
          userId,
          token: dto.token,
          platform: dto.platform || 'ANDROID',
          deviceId: dto.deviceId,
          appVersion: dto.appVersion,
          isActive: true,
          lastSeenAt: new Date(),
        },
      });
    }

    // Update legacy fcmToken on User for backwards compatibility
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: dto.token },
    });

    return device;
  }

  async unregisterDevice(userId: string, token: string) {
    const res = await this.prisma.userDevice.updateMany({
      where: { userId, token },
      data: { isActive: false },
    });

    // Also clear from User table if this token was the legacy user.fcmToken
    if (this.prisma.user?.updateMany) {
      await this.prisma.user.updateMany({
        where: { id: userId, fcmToken: token },
        data: { fcmToken: null },
      });
    }

    return res;
  }

  async getUserDevices(userId: string) {
    return this.prisma.userDevice.findMany({
      where: { userId, isActive: true },
      select: {
        id: true,
        platform: true,
        deviceId: true,
        appVersion: true,
        lastSeenAt: true,
        createdAt: true,
      },
      orderBy: { lastSeenAt: 'desc' },
    });
  }

  async revokeDevice(userId: string, deviceIdOrId: string) {
    const res = await this.prisma.userDevice.updateMany({
      where: {
        userId,
        OR: [{ id: deviceIdOrId }, { deviceId: deviceIdOrId }],
      },
      data: { isActive: false },
    });
    return { success: true, count: res.count };
  }

  async cleanupStaleDevices(staleDays = 90) {
    const cutoff = new Date(Date.now() - staleDays * 24 * 60 * 60 * 1000);
    const result = await this.prisma.userDevice.updateMany({
      where: {
        isActive: true,
        lastSeenAt: { lt: cutoff },
      },
      data: { isActive: false },
    });
    this.logger.log(
      `[STALE-DEVICE-CLEANUP] Deactivated ${result.count} stale devices (seen before ${cutoff.toISOString()})`,
    );
    return { cleanedCount: result.count };
  }

  // ── Notification Preferences ──────────────────────────────────────────────

  async getPreferences(userId: string) {
    let prefs = await this.prisma.notificationPreference.findUnique({
      where: { userId },
    });

    if (!prefs) {
      prefs = await this.prisma.notificationPreference.create({
        data: { userId },
      });
    }

    return prefs;
  }

  async updatePreferences(
    userId: string,
    dto: UpdateNotificationPreferencesDto,
  ) {
    return this.prisma.notificationPreference.upsert({
      where: { userId },
      update: { ...dto },
      create: { userId, ...dto },
    });
  }

  // ── Customer & Vendor In-App Notification Center ──────────────────────────

  async getMyNotifications(
    userId: string,
    page = 1,
    limit = 20,
    unreadOnly = false,
    category?: string,
  ) {
    const skip = (page - 1) * limit;
    const where: any = { userId };

    if (unreadOnly) {
      where.isRead = false;
    }
    if (category) {
      where.category = category;
    }

    const [notifications, total, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { userId, isRead: false } }),
    ]);

    return {
      notifications,
      total,
      unreadCount,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { userId, isRead: false },
    });
  }

  async markAsRead(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId },
    });

    if (!notification || notification.userId !== userId) {
      throw new NotFoundException('Notification not found.');
    }

    const updated = await this.prisma.notification.update({
      where: { id: notificationId },
      data: {
        isRead: true,
        readAt: notification.readAt ?? new Date(),
      },
    });

    // Realtime unread count sync
    if (this.realtimeService) {
      const count = await this.prisma.notification.count({
        where: { userId, isRead: false },
      });
      this.realtimeService.emitToUser(userId, 'unread_count', { unreadCount: count });
      this.realtimeService.emitToUser(userId, 'read', { notificationId });
    }

    return updated;
  }

  async markAllAsRead(userId: string) {
    const res = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });

    if (this.realtimeService) {
      this.realtimeService.emitToUser(userId, 'unread_count', { unreadCount: 0 });
    }

    return res;
  }

  // ── Admin Broadcasts & History ────────────────────────────────────────────

  async sendBulk(
    dto: { target: string; title: string; body: string; category?: string },
    adminUserId?: string,
  ) {
    const { target, title, body, category = 'SYSTEM' } = dto;

    const broadcast = await this.prisma.sentBroadcast.create({
      data: { target, title, body },
    });

    if (adminUserId) {
      await this.auditLogService.log(
        adminUserId,
        'NOTIFICATION_SENT',
        'SentBroadcast',
        broadcast.id,
        { target, title, body },
      );
    }

    let users: { id: string }[] = [];

    if (target === 'ALL_USERS') {
      users = await this.prisma.user.findMany({ select: { id: true } });
    } else if (target === 'ALL_VENDORS') {
      users = await this.prisma.user.findMany({
        where: { role: Role.VENDOR },
        select: { id: true },
      });
    } else if (target.startsWith('CITY:')) {
      const cityName = target.replace('CITY:', '').trim();
      users = await this.prisma.user.findMany({
        where: {
          role: Role.VENDOR,
          vendor: { city: { equals: cityName, mode: 'insensitive' } },
        },
        select: { id: true },
      });
    } else if (target.startsWith('USER:')) {
      const userId = target.replace('USER:', '').trim();
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true },
      });
      if (user) users = [user];
    }

    if (users.length === 0) {
      return { sentCount: 0, pushCount: 0 };
    }

    // Create notifications in batch
    await this.prisma.notification.createMany({
      data: users.map((u) => ({
        userId: u.id,
        title,
        body,
        category,
        isRead: false,
      })),
    });

    // Gather active device tokens
    const devices = await this.prisma.userDevice.findMany({
      where: {
        userId: { in: users.map((u) => u.id) },
        isActive: true,
      },
      select: { token: true },
    });

    const tokens = devices.map((d) => d.token);
    if (tokens.length > 0) {
      await this.fcmService.sendMulticast(tokens, title, body);
    }

    return { sentCount: users.length, pushCount: tokens.length };
  }

  async getHistory(page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.prisma.sentBroadcast.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.sentBroadcast.count(),
    ]);

    return {
      items,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ── Retention Cleanup ─────────────────────────────────────────────────────

  async cleanupOldNotifications() {
    const config = this.systemConfigService
      ? await this.systemConfigService.getNotificationConfig()
      : { retentionDaysMarketing: 30, retentionDaysTransactional: 365 };

    const marketingCutoff = new Date(
      Date.now() - (config.retentionDaysMarketing || 30) * 86400000,
    );

    const deletedMarketing = await this.prisma.notification.deleteMany({
      where: {
        category: 'GROWTH',
        createdAt: { lt: marketingCutoff },
        isRead: true,
      },
    });

    this.logger.log(
      `[RETENTION CLEANUP] Cleaned up ${deletedMarketing.count} old marketing notifications.`,
    );

    return { deletedMarketingCount: deletedMarketing.count };
  }
}
