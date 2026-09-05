import {
  Injectable,
  Logger,
  Optional,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FcmService } from './fcm.service';
import { SmsProvider } from './providers/sms-provider.service';
import { EmailProvider } from './providers/email-provider.service';
import { WhatsAppProvider } from '../whatsapp/whatsapp-provider.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import {
  NotificationTemplateEngine,
  OperationalEventType,
  TemplateVariables,
  RenderedNotificationPayload,
} from './templates/notification-templates';
import {
  NotificationChannel,
  DeliveryStatus,
  NotificationPriority,
  Prisma,
} from '@prisma/client';

export interface PublishOperationalEventDto {
  eventType: OperationalEventType;
  recipientId: string;
  entityType?: string; // 'BOOKING', 'PAYMENT', 'CAR'
  entityId?: string; // bookingId, paymentId
  variables: TemplateVariables;
  idempotencyKey?: string;
  priority?: 'HIGH' | 'NORMAL' | 'LOW';
  channels?: NotificationChannel[];
  isTransactional?: boolean;
}

export interface DeliveryQueryDto {
  page?: number;
  limit?: number;
  channel?: NotificationChannel;
  status?: DeliveryStatus;
  recipient?: string;
  notificationId?: string;
}

@Injectable()
export class NotificationOrchestratorService {
  private readonly logger = new Logger(NotificationOrchestratorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcmService: FcmService,
    private readonly smsProvider: SmsProvider,
    private readonly emailProvider: EmailProvider,
    @Optional() private readonly whatsappProvider?: WhatsAppProvider,
    @Optional() private readonly queueProducer?: QueueProducerService,
  ) {}

  /**
   * Publishes an operational lifecycle event to all eligible channels.
   * Enforces server-side deduplication, recipient resolution, template rendering, and delivery tracking.
   */
  async publishEvent(dto: PublishOperationalEventDto) {
    const {
      eventType,
      recipientId,
      entityType,
      entityId,
      variables,
      priority: overridePriority,
      channels: overrideChannels,
      isTransactional = true,
    } = dto;

    // 1. Resolve Recipient User & Contact Info
    const user = await this.prisma.user.findUnique({
      where: { id: recipientId },
      select: { id: true, name: true, phone: true, email: true },
    });

    if (!user) {
      this.logger.warn(`[NOTIF-ORCHESTRATOR] Recipient user ${recipientId} not found. Skipping.`);
      return null;
    }

    // Enhance variables with user name if not present
    const enrichedVars: TemplateVariables = {
      customerName: user.name || 'Customer',
      ...variables,
    };

    // 2. Render Canonical Template
    const rendered = NotificationTemplateEngine.render(eventType, enrichedVars);
    const priority = (overridePriority || rendered.priority) as NotificationPriority;

    // 3. Generate Deterministic Idempotency Key
    const idempotencyKey =
      dto.idempotencyKey ||
      `evt_${eventType}_${entityId || 'none'}_${recipientId}`;

    // 4. Permanent Idempotency Check (Database Uniqueness)
    const existing = await this.prisma.notification.findUnique({
      where: { idempotencyKey },
      include: { deliveries: true },
    });

    if (existing) {
      this.logger.log(
        `[NOTIF-ORCHESTRATOR] Idempotent notification hit for key: ${idempotencyKey}. Returning existing record.`,
      );
      return existing;
    }

    // 5. Check User Channel Preferences
    const prefs = await this.getUserPreferences(recipientId);

    // Determine enabled channels
    const channelsToDispatch: NotificationChannel[] = overrideChannels || [
      NotificationChannel.IN_APP,
      ...(isTransactional || prefs.promotionalPush ? [NotificationChannel.PUSH] : []),
      ...((isTransactional ? prefs.operationalSms : prefs.promotionalSms) && user.phone
        ? [NotificationChannel.SMS]
        : []),
      ...((isTransactional ? prefs.operationalWhatsApp : prefs.promotionalWhatsApp) && user.phone
        ? [NotificationChannel.WHATSAPP]
        : []),
      ...((isTransactional ? prefs.operationalEmail : prefs.promotionalEmail) && user.email
        ? [NotificationChannel.EMAIL]
        : []),
    ];

    // 6. Synchronously Persist Canonical In-App Notification (Single Source of Truth)
    const notification = await this.prisma.notification.create({
      data: {
        userId: recipientId,
        title: rendered.title,
        body: rendered.body,
        category: rendered.category,
        eventType,
        entityType,
        entityId,
        actionUrl: rendered.actionUrl,
        priority,
        idempotencyKey,
        metadata: variables as any,
        isRead: false,
      },
    });

    // 7. Create NotificationDelivery Records and Dispatch to Channels
    const deliveries: any[] = [];

    for (const channel of channelsToDispatch) {
      const channelIdempotencyKey = `${idempotencyKey}_${channel}`;
      const recipientTarget =
        channel === NotificationChannel.SMS || channel === NotificationChannel.WHATSAPP
          ? user.phone || recipientId
          : channel === NotificationChannel.EMAIL
            ? user.email || recipientId
            : recipientId;

      const delivery = await this.prisma.notificationDelivery.create({
        data: {
          notificationId: notification.id,
          channel,
          status:
            channel === NotificationChannel.IN_APP
              ? DeliveryStatus.DELIVERED
              : DeliveryStatus.QUEUED,
          recipient: recipientTarget,
          provider:
            channel === NotificationChannel.PUSH
              ? 'FCM'
              : channel === NotificationChannel.SMS
                ? 'TWILIO'
                : channel === NotificationChannel.WHATSAPP
                  ? 'META'
                  : channel === NotificationChannel.EMAIL
                    ? 'SMTP'
                    : 'IN_APP',
          idempotencyKey: channelIdempotencyKey,
          deliveredAt: channel === NotificationChannel.IN_APP ? new Date() : null,
          metadata: {
            eventType,
            priority,
          },
        },
      });

      deliveries.push(delivery);

      // Asynchronously trigger channel dispatch
      this.dispatchChannel(channel, delivery.id, recipientId, user, rendered).catch(
        (err) => {
          this.logger.error(
            `[CHANNEL-DISPATCH-ERROR] Failed to dispatch channel ${channel} for delivery ${delivery.id}: ${err?.message}`,
          );
        },
      );
    }

    return {
      ...notification,
      deliveries,
    };
  }

  // ── Asynchronous Channel Dispatcher ───────────────────────────────────────

  private async dispatchChannel(
    channel: NotificationChannel,
    deliveryId: string,
    recipientId: string,
    user: { id: string; name: string | null; phone: string | null; email: string | null },
    rendered: RenderedNotificationPayload,
  ) {
    switch (channel) {
      case NotificationChannel.IN_APP:
        // Already marked DELIVERED upon creation
        break;

      case NotificationChannel.PUSH:
        if (this.queueProducer) {
          await this.queueProducer.dispatchPushNotification({
            userId: recipientId,
            title: rendered.title,
            body: rendered.body,
            data: {
              actionUrl: rendered.actionUrl || '',
              category: rendered.category,
            },
            correlationId: deliveryId,
          });
        } else {
          // Direct execution fallback
          await this.executePushDelivery(deliveryId, recipientId, rendered.title, rendered.body, {
            actionUrl: rendered.actionUrl || '',
            category: rendered.category,
          });
        }
        break;

      case NotificationChannel.SMS:
        if (user.phone) {
          if (this.queueProducer) {
            await this.queueProducer.dispatchSmsNotification({
              phone: user.phone,
              message: rendered.smsText,
              correlationId: deliveryId,
            });
          } else {
            // Direct execution fallback
            await this.executeSmsDelivery(deliveryId, user.phone, rendered.smsText);
          }
        }
        break;

      case NotificationChannel.WHATSAPP:
        if (user.phone) {
          if (this.queueProducer) {
            await this.queueProducer.dispatchWhatsAppNotification({
              phone: user.phone,
              templateName: rendered.whatsappTemplate,
              bodyParameters: rendered.whatsappParams,
              userId: recipientId,
              correlationId: deliveryId,
            });
          } else {
            // Direct execution fallback
            await this.executeWhatsAppDelivery(
              deliveryId,
              user.phone,
              rendered.whatsappTemplate,
              rendered.whatsappParams,
            );
          }
        }
        break;

      case NotificationChannel.EMAIL:
        if (user.email) {
          if (this.queueProducer) {
            await this.queueProducer.dispatchEmailNotification({
              to: user.email,
              subject: rendered.emailSubject,
              htmlContent: rendered.emailHtml,
              correlationId: deliveryId,
            });
          } else {
            // Direct execution fallback
            await this.executeEmailDelivery(
              deliveryId,
              user.email,
              rendered.emailSubject,
              rendered.emailHtml,
            );
          }
        }
        break;
    }
  }

  // ── Direct Execution Workers (used directly or by BullMQ processor) ───────

  async executePushDelivery(
    deliveryId: string,
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ) {
    try {
      const result = await this.fcmService.sendToUser(userId, title, body, data);
      await this.prisma.notificationDelivery.update({
        where: { id: deliveryId },
        data: {
          status: result?.success !== false ? DeliveryStatus.DELIVERED : DeliveryStatus.FAILED,
          providerMessageId: result?.messageId || null,
          deliveredAt: result?.success !== false ? new Date() : null,
          failedAt: result?.success === false ? new Date() : null,
          lastError: result?.error || null,
          attemptCount: { increment: 1 },
        },
      });
      return result;
    } catch (err: any) {
      await this.recordDeliveryFailure(deliveryId, err?.message);
      throw err;
    }
  }

  async executeSmsDelivery(deliveryId: string, phone: string, message: string) {
    try {
      const result = await this.smsProvider.sendSms(phone, message);
      await this.prisma.notificationDelivery.update({
        where: { id: deliveryId },
        data: {
          status: result.success ? DeliveryStatus.DELIVERED : DeliveryStatus.FAILED,
          providerMessageId: result.messageId || null,
          deliveredAt: result.success ? new Date() : null,
          failedAt: !result.success ? new Date() : null,
          lastError: result.error || null,
          attemptCount: { increment: 1 },
        },
      });
      return result;
    } catch (err: any) {
      await this.recordDeliveryFailure(deliveryId, err?.message);
      throw err;
    }
  }

  async executeWhatsAppDelivery(
    deliveryId: string,
    phone: string,
    templateName: string,
    params: string[],
  ) {
    try {
      if (!this.whatsappProvider) {
        this.logger.warn(`[NOTIF-ORCHESTRATOR] WhatsAppProvider not available. Skipping.`);
        return { success: true };
      }
      const result = await this.whatsappProvider.sendMessage(
        phone,
        templateName,
        'en_US',
        params,
      );
      await this.prisma.notificationDelivery.update({
        where: { id: deliveryId },
        data: {
          status: DeliveryStatus.DELIVERED,
          providerMessageId: result.providerMessageId,
          deliveredAt: new Date(),
          attemptCount: { increment: 1 },
        },
      });
      return { success: true, messageId: result.providerMessageId };
    } catch (err: any) {
      await this.recordDeliveryFailure(deliveryId, err?.message);
      throw err;
    }
  }

  async executeEmailDelivery(
    deliveryId: string,
    to: string,
    subject: string,
    html: string,
  ) {
    try {
      const result = await this.emailProvider.sendEmail(to, subject, html);
      await this.prisma.notificationDelivery.update({
        where: { id: deliveryId },
        data: {
          status: result.success ? DeliveryStatus.DELIVERED : DeliveryStatus.FAILED,
          providerMessageId: result.messageId || null,
          deliveredAt: result.success ? new Date() : null,
          failedAt: !result.success ? new Date() : null,
          lastError: result.error || null,
          attemptCount: { increment: 1 },
        },
      });
      return result;
    } catch (err: any) {
      await this.recordDeliveryFailure(deliveryId, err?.message);
      throw err;
    }
  }

  private async recordDeliveryFailure(deliveryId: string, errorMessage?: string) {
    const existing = await this.prisma.notificationDelivery.findUnique({
      where: { id: deliveryId },
    });

    if (!existing) return;

    const nextAttempt = existing.attemptCount + 1;
    const isExhausted = nextAttempt >= existing.maxRetries;

    await this.prisma.notificationDelivery.update({
      where: { id: deliveryId },
      data: {
        status: isExhausted ? DeliveryStatus.DEAD_LETTER : DeliveryStatus.FAILED,
        attemptCount: nextAttempt,
        lastError: errorMessage || 'Channel delivery failed',
        failedAt: new Date(),
      },
    });
  }

  // ── User Preference Resolution ────────────────────────────────────────────

  private async getUserPreferences(userId: string) {
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

  // ── Admin Delivery Telemetry & Observability ──────────────────────────────

  async getDeliveries(query: DeliveryQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.NotificationDeliveryWhereInput = {};
    if (query.channel) where.channel = query.channel;
    if (query.status) where.status = query.status;
    if (query.recipient) {
      where.recipient = { contains: query.recipient, mode: 'insensitive' };
    }
    if (query.notificationId) where.notificationId = query.notificationId;

    const [items, total] = await Promise.all([
      this.prisma.notificationDelivery.findMany({
        where,
        include: {
          notification: {
            select: {
              title: true,
              eventType: true,
              category: true,
              userId: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.notificationDelivery.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getDeliveryStats() {
    const [total, delivered, failed, deadLetter, queued] = await Promise.all([
      this.prisma.notificationDelivery.count(),
      this.prisma.notificationDelivery.count({ where: { status: DeliveryStatus.DELIVERED } }),
      this.prisma.notificationDelivery.count({ where: { status: DeliveryStatus.FAILED } }),
      this.prisma.notificationDelivery.count({ where: { status: DeliveryStatus.DEAD_LETTER } }),
      this.prisma.notificationDelivery.count({ where: { status: DeliveryStatus.QUEUED } }),
    ]);

    const channelStats = await this.prisma.notificationDelivery.groupBy({
      by: ['channel', 'status'],
      _count: { id: true },
    });

    return {
      overview: {
        total,
        delivered,
        failed,
        deadLetter,
        queued,
        deliveryRate: total > 0 ? ((delivered / total) * 100).toFixed(1) + '%' : '100%',
      },
      channelBreakdown: channelStats,
    };
  }

  async retryDelivery(deliveryId: string) {
    const delivery = await this.prisma.notificationDelivery.findUnique({
      where: { id: deliveryId },
      include: { notification: true },
    });

    if (!delivery) {
      throw new NotFoundException(`Notification delivery ${deliveryId} not found.`);
    }

    if (delivery.status === DeliveryStatus.DELIVERED) {
      throw new BadRequestException(`Delivery ${deliveryId} is already marked DELIVERED.`);
    }

    const user = await this.prisma.user.findUnique({
      where: { id: delivery.notification.userId },
      select: { id: true, name: true, phone: true, email: true },
    });

    if (!user) {
      throw new NotFoundException(`User for delivery ${deliveryId} not found.`);
    }

    const rendered = NotificationTemplateEngine.render(
      (delivery.notification.eventType as OperationalEventType) || 'BOOKING_CONFIRMED',
      {
        customerName: user.name || 'Customer',
        bookingId: delivery.notification.entityId || '',
        ...(delivery.notification.metadata as any),
      },
    );

    // Reset status to QUEUED
    await this.prisma.notificationDelivery.update({
      where: { id: deliveryId },
      data: {
        status: DeliveryStatus.QUEUED,
        lastError: null,
      },
    });

    // Re-dispatch
    await this.dispatchChannel(
      delivery.channel,
      delivery.id,
      delivery.notification.userId,
      user,
      rendered,
    );

    return { success: true, deliveryId, status: 'QUEUED' };
  }
}
