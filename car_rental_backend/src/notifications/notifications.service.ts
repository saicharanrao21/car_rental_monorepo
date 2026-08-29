import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FcmService } from './fcm.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import { Role } from '@prisma/client';

import { AuditLogService } from '../admin/audit-log.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private prisma: PrismaService,
    private fcmService: FcmService,
    private auditLogService: AuditLogService,
    @Optional() private queueProducer?: QueueProducerService,
  ) {}

  async notifyUser(userId: string, title: string, body: string) {
    // 1. Create in-app notification in DB (synchronous for immediate UI rendering)
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        title,
        body,
        isRead: false,
      },
    });

    // 2. Trigger FCM push notification
    await this.fcmService.sendToUser(userId, title, body);

    // 3. If QueueProducer is available, enqueue async notification job for channel delivery
    if (this.queueProducer) {
      this.prisma.user
        .findUnique({
          where: { id: userId },
          select: { phone: true, email: true },
        })
        .then((u) => {
          if (u?.phone && this.queueProducer) {
            this.queueProducer.dispatchSmsNotification({
              phone: u.phone,
              message: `${title}: ${body}`,
            }).catch((err) => this.logger.warn(`Async SMS enqueue error: ${err?.message}`));
          }
          if (u?.email && this.queueProducer) {
            this.queueProducer.dispatchEmailNotification({
              to: u.email,
              subject: title,
              htmlContent: `<p>${body}</p>`,
            }).catch((err) => this.logger.warn(`Async Email enqueue error: ${err?.message}`));
          }
        })
        .catch((err) => this.logger.warn(`Failed resolving user for async notification: ${err?.message}`));
    }

    return notification;
  }

  async sendBulk(
    dto: { target: string; title: string; body: string },
    adminUserId?: string,
  ) {
    const { target, title, body } = dto;

    // 1. Log the broadcast broadcast in SentBroadcast
    const broadcast = await this.prisma.sentBroadcast.create({
      data: {
        target,
        title,
        body,
      },
    });

    if (adminUserId) {
      this.auditLogService.log(
        adminUserId,
        'NOTIFICATION_SENT',
        'SentBroadcast',
        broadcast.id,
        { target, title, body },
      );
    }

    // 2. Resolve users and their fcmTokens
    let users: { id: string; fcmToken: string | null }[] = [];

    if (target === 'ALL_USERS') {
      users = await this.prisma.user.findMany({
        select: { id: true, fcmToken: true },
      });
    } else if (target === 'ALL_VENDORS') {
      users = await this.prisma.user.findMany({
        where: { role: Role.VENDOR },
        select: { id: true, fcmToken: true },
      });
    } else if (target.startsWith('CITY:')) {
      const cityName = target.replace('CITY:', '').trim();
      users = await this.prisma.user.findMany({
        where: {
          role: Role.VENDOR,
          vendor: {
            city: {
              equals: cityName,
              mode: 'insensitive',
            },
          },
        },
        select: { id: true, fcmToken: true },
      });
    } else if (target.startsWith('USER:')) {
      const userId = target.replace('USER:', '').trim();
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, fcmToken: true },
      });
      if (user) {
        users = [user];
      }
    }

    if (users.length === 0) {
      this.logger.log(
        `Bulk notification broadcast for target: ${target} resolved to 0 users.`,
      );
      return { sentCount: 0 };
    }

    // 3. Create Notification records for each resolved user in DB
    await this.prisma.notification.createMany({
      data: users.map((u) => ({
        userId: u.id,
        title,
        body,
        isRead: false,
      })),
    });

    // 4. Gather active FCM tokens and send via multicast
    const tokens = users.map((u) => u.fcmToken).filter((t): t is string => !!t);
    if (tokens.length > 0) {
      await this.fcmService.sendMulticast(tokens, title, body);
    }

    return { sentCount: users.length, pushCount: tokens.length };
  }

  async getHistory(page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.sentBroadcast.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.sentBroadcast.count(),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getMyNotifications(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where: { userId } }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { success: true };
  }
}
