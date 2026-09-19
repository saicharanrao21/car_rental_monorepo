import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { WhatsAppProvider } from './whatsapp-provider.service';
import {
  SendTemplateOptions,
  WhatsAppSummaryResponse,
  WhatsAppWebhookPayload,
} from './whatsapp.types';
import {
  WhatsAppMessage,
  WhatsAppMessageStatus,
  WhatsAppMessageType,
} from '@prisma/client';
import * as crypto from 'crypto';

@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);
  private readonly appSecret: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly whatsappProvider: WhatsAppProvider,
    private readonly auditLogService: AuditLogService,
    private readonly configService: ConfigService,
  ) {
    this.appSecret = this.configService.get<string>('WHATSAPP_APP_SECRET') || '';
  }

  /**
   * Normalizes an Indian or international phone number to E.164 standard.
   */
  normalizePhoneNumber(phone: string): string {
    if (!phone || typeof phone !== 'string') {
      throw new BadRequestException('Phone number is required and must be a string.');
    }

    const digitsOnly = phone.replace(/\D/g, '');

    if (digitsOnly.length === 10) {
      return `+91${digitsOnly}`;
    } else if (digitsOnly.length === 12 && digitsOnly.startsWith('91')) {
      return `+${digitsOnly}`;
    } else if (digitsOnly.length >= 7 && digitsOnly.length <= 15) {
      return `+${digitsOnly}`;
    }

    throw new BadRequestException(`Invalid phone number format: ${phone}`);
  }

  /**
   * Resolves template variables into ordered positional body parameters.
   */
  getTemplateParameters(
    templateName: string,
    variables: Record<string, any>,
  ): string[] {
    switch (templateName) {
      case 'booking_confirmed':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.carName || 'Vehicle'),
          String(variables.pickupDate || ''),
          String(variables.pickupLocation || ''),
          String(variables.totalFare ? `₹${variables.totalFare}` : ''),
        ];
      case 'booking_cancelled':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.cancellationReason || 'Requested by user'),
          String(variables.refundAmount ? `₹${variables.refundAmount}` : '₹0'),
        ];
      case 'payment_successful':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.amount ? `₹${variables.amount}` : ''),
          String(variables.paymentId || ''),
        ];
      case 'refund_processed':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.refundAmount ? `₹${variables.refundAmount}` : ''),
          String(variables.refundId || ''),
        ];
      case 'handover_ready':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.carName || 'Vehicle'),
          String(variables.pickupLocation || ''),
        ];
      case 'trip_reminder':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.bookingId || ''),
          String(variables.startDate || ''),
          String(variables.pickupLocation || ''),
        ];
      case 'emergency_alert':
        return [
          String(variables.customerName || 'Valued Customer'),
          String(variables.incidentType || 'Emergency'),
          String(variables.locationAddress || 'Current Location'),
          String(variables.requestNumber || ''),
        ];
      default:
        return Object.values(variables).map((v) => String(v));
    }
  }

  /**
   * Idempotently sends a transactional WhatsApp message via template.
   */
  async sendTemplateMessage(
    options: SendTemplateOptions,
  ): Promise<WhatsAppMessage> {
    const {
      userId,
      bookingId,
      phoneNumber,
      messageType,
      templateName,
      templateLanguage = 'en_US',
      variables,
      idempotencyKey,
    } = options;

    // 1. Idempotency Check: Return existing record if already dispatched
    const existing = await this.prisma.whatsAppMessage.findUnique({
      where: { idempotencyKey },
    });
    if (existing) {
      this.logger.log(
        `Idempotent hit for WhatsApp message: ${idempotencyKey}. Status: ${existing.status}`,
      );
      return existing;
    }

    // 2. Normalize recipient phone number
    const normalizedPhone = this.normalizePhoneNumber(phoneNumber);

    // 3. Resolve positional body parameters
    const bodyParameters = this.getTemplateParameters(templateName, variables);

    // 4. Create initial DB record in QUEUED state
    const createdMessage = await this.prisma.whatsAppMessage.create({
      data: {
        userId,
        bookingId,
        phoneNumber: normalizedPhone,
        templateName,
        templateLanguage,
        messageType,
        status: WhatsAppMessageStatus.QUEUED,
        idempotencyKey,
        variables: variables as any,
      },
    });

    // 5. Send via Provider
    const result = await this.whatsappProvider.sendMessage(
      normalizedPhone,
      templateName,
      templateLanguage,
      bodyParameters,
    );

    // 6. Update message status based on provider response
    if (result.status === 'ACCEPTED') {
      return this.prisma.whatsAppMessage.update({
        where: { id: createdMessage.id },
        data: {
          status: WhatsAppMessageStatus.SENT,
          providerMessageId: result.providerMessageId,
          sentAt: new Date(),
        },
      });
    } else {
      return this.prisma.whatsAppMessage.update({
        where: { id: createdMessage.id },
        data: {
          status: WhatsAppMessageStatus.FAILED,
          providerMessageId: result.providerMessageId,
          failureCode: result.errorCode,
          failureReason: result.errorMessage,
          failedAt: new Date(),
        },
      });
    }
  }

  // --- Domain Event Helpers ---

  async sendBookingConfirmed(booking: {
    id: string;
    customerId: string;
    customerPhone: string;
    customerName: string;
    carName: string;
    pickupDate: string;
    pickupLocation: string;
    totalFare: number;
  }) {
    return this.sendTemplateMessage({
      userId: booking.customerId,
      bookingId: booking.id,
      phoneNumber: booking.customerPhone,
      messageType: WhatsAppMessageType.BOOKING_CONFIRMED,
      templateName: 'booking_confirmed',
      variables: {
        customerName: booking.customerName,
        bookingId: booking.id,
        carName: booking.carName,
        pickupDate: booking.pickupDate,
        pickupLocation: booking.pickupLocation,
        totalFare: booking.totalFare,
      },
      idempotencyKey: `whatsapp_booking_confirmed_${booking.id}`,
    });
  }

  async sendBookingCancelled(
    booking: {
      id: string;
      customerId: string;
      customerPhone: string;
      customerName: string;
    },
    cancellationReason: string,
    refundAmount: number = 0,
  ) {
    return this.sendTemplateMessage({
      userId: booking.customerId,
      bookingId: booking.id,
      phoneNumber: booking.customerPhone,
      messageType: WhatsAppMessageType.BOOKING_CANCELLED,
      templateName: 'booking_cancelled',
      variables: {
        customerName: booking.customerName,
        bookingId: booking.id,
        cancellationReason,
        refundAmount,
      },
      idempotencyKey: `whatsapp_booking_cancelled_${booking.id}`,
    });
  }

  async sendPaymentSuccessful(
    payment: { id: string; amount: number },
    booking: {
      id: string;
      customerId: string;
      customerPhone: string;
      customerName: string;
    },
  ) {
    return this.sendTemplateMessage({
      userId: booking.customerId,
      bookingId: booking.id,
      phoneNumber: booking.customerPhone,
      messageType: WhatsAppMessageType.PAYMENT_SUCCESSFUL,
      templateName: 'payment_successful',
      variables: {
        customerName: booking.customerName,
        bookingId: booking.id,
        amount: payment.amount,
        paymentId: payment.id,
      },
      idempotencyKey: `whatsapp_payment_success_${payment.id}`,
    });
  }

  async sendRefundProcessed(
    refund: { id: string; amount: number },
    booking: {
      id: string;
      customerId: string;
      customerPhone: string;
      customerName: string;
    },
  ) {
    return this.sendTemplateMessage({
      userId: booking.customerId,
      bookingId: booking.id,
      phoneNumber: booking.customerPhone,
      messageType: WhatsAppMessageType.REFUND_PROCESSED,
      templateName: 'refund_processed',
      variables: {
        customerName: booking.customerName,
        bookingId: booking.id,
        refundAmount: refund.amount,
        refundId: refund.id,
      },
      idempotencyKey: `whatsapp_refund_${refund.id}`,
    });
  }

  async sendEmergencyAlert(emergency: {
    requestNumber: string;
    customerId: string;
    customerPhone: string;
    customerName: string;
    incidentType: string;
    locationAddress?: string;
  }) {
    return this.sendTemplateMessage({
      userId: emergency.customerId,
      phoneNumber: emergency.customerPhone,
      messageType: WhatsAppMessageType.EMERGENCY_ALERT,
      templateName: 'emergency_alert',
      variables: {
        customerName: emergency.customerName,
        incidentType: emergency.incidentType,
        locationAddress: emergency.locationAddress || 'Current GPS Location',
        requestNumber: emergency.requestNumber,
      },
      idempotencyKey: `whatsapp_emergency_${emergency.requestNumber}`,
    });
  }

  // --- Webhook Processing ---

  /**
   * Verifies the x-hub-signature-256 header sent by Meta Webhooks.
   */
  verifyWebhookSignature(rawBody: string, signatureHeader?: string): boolean {
    if (!this.appSecret) {
      return true; // If secret is not set in dev, pass gracefully
    }
    if (!signatureHeader) {
      return false;
    }

    const expectedSignature = `sha256=${crypto
      .createHmac('sha256', this.appSecret)
      .update(rawBody)
      .digest('hex')}`;

    return crypto.timingSafeEqual(
      Buffer.from(signatureHeader),
      Buffer.from(expectedSignature),
    );
  }

  /**
   * Processes inbound webhook delivery status receipts with monotonic transition safety.
   */
  async handleWebhookEvent(
    payload: WhatsAppWebhookPayload,
  ): Promise<{ processed: number }> {
    let processed = 0;
    const entries = payload.entry || [];

    for (const entry of entries) {
      const changes = entry.changes || [];
      for (const change of changes) {
        const statuses = change.value?.statuses || [];
        for (const statusItem of statuses) {
          const providerMessageId = statusItem.id;
          const status = statusItem.status;

          const msg = await this.prisma.whatsAppMessage.findUnique({
            where: { providerMessageId },
          });

          if (!msg) {
            continue;
          }

          if (status === 'delivered') {
            // Monotonic: only transition if currently QUEUED or SENT
            if (
              msg.status === WhatsAppMessageStatus.QUEUED ||
              msg.status === WhatsAppMessageStatus.SENT
            ) {
              await this.prisma.whatsAppMessage.update({
                where: { id: msg.id },
                data: {
                  status: WhatsAppMessageStatus.DELIVERED,
                  deliveredAt: new Date(),
                },
              });
              processed++;
            }
          } else if (status === 'read') {
            // Monotonic: transition if not already READ
            if (msg.status !== WhatsAppMessageStatus.READ) {
              await this.prisma.whatsAppMessage.update({
                where: { id: msg.id },
                data: {
                  status: WhatsAppMessageStatus.READ,
                  readAt: new Date(),
                },
              });
              processed++;
            }
          } else if (status === 'failed') {
            const firstError = statusItem.errors?.[0];
            await this.prisma.whatsAppMessage.update({
              where: { id: msg.id },
              data: {
                status: WhatsAppMessageStatus.FAILED,
                failureCode: firstError?.code?.toString() || 'WEBHOOK_FAILED',
                failureReason: firstError?.title || firstError?.message || 'Message delivery failed',
                failedAt: new Date(),
              },
            });
            processed++;
          }
        }
      }
    }

    return { processed };
  }

  // --- Admin Queries & Operations ---

  async getSummary(): Promise<WhatsAppSummaryResponse> {
    const [total, sent, delivered, read, failed] = await Promise.all([
      this.prisma.whatsAppMessage.count(),
      this.prisma.whatsAppMessage.count({
        where: { status: WhatsAppMessageStatus.SENT },
      }),
      this.prisma.whatsAppMessage.count({
        where: { status: WhatsAppMessageStatus.DELIVERED },
      }),
      this.prisma.whatsAppMessage.count({
        where: { status: WhatsAppMessageStatus.READ },
      }),
      this.prisma.whatsAppMessage.count({
        where: { status: WhatsAppMessageStatus.FAILED },
      }),
    ]);

    const successfulDeliveries = delivered + read;
    const deliveryRatePercent =
      total > 0
        ? Number(((successfulDeliveries / total) * 100).toFixed(1))
        : 100.0;

    return {
      totalMessages: total,
      sentCount: sent,
      deliveredCount: delivered,
      readCount: read,
      failedCount: failed,
      deliveryRatePercent,
    };
  }

  async getMessages(query: {
    status?: WhatsAppMessageStatus;
    messageType?: WhatsAppMessageType;
    search?: string;
    skip?: number;
    take?: number;
  }) {
    const { status, messageType, search, skip = 0, take = 50 } = query;

    const where: any = {};
    if (status) where.status = status;
    if (messageType) where.messageType = messageType;
    if (search) {
      where.OR = [
        { phoneNumber: { contains: search } },
        { bookingId: { contains: search } },
        { templateName: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.whatsAppMessage.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: Number(skip),
        take: Number(take),
      }),
      this.prisma.whatsAppMessage.count({ where }),
    ]);

    return { items, total };
  }

  async resendMessage(id: string, adminUserId: string): Promise<WhatsAppMessage> {
    const msg = await this.prisma.whatsAppMessage.findUnique({
      where: { id },
    });

    if (!msg) {
      throw new NotFoundException(`WhatsApp message with ID ${id} not found.`);
    }

    const bodyParameters = this.getTemplateParameters(
      msg.templateName,
      (msg.variables as Record<string, any>) || {},
    );

    const result = await this.whatsappProvider.sendMessage(
      msg.phoneNumber,
      msg.templateName,
      msg.templateLanguage,
      bodyParameters,
    );

    const updated = await this.prisma.whatsAppMessage.update({
      where: { id: msg.id },
      data: {
        status:
          result.status === 'ACCEPTED'
            ? WhatsAppMessageStatus.SENT
            : WhatsAppMessageStatus.FAILED,
        providerMessageId: result.providerMessageId,
        sentAt: result.status === 'ACCEPTED' ? new Date() : msg.sentAt,
        failureCode: result.status === 'FAILED' ? result.errorCode : null,
        failureReason: result.status === 'FAILED' ? result.errorMessage : null,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'WHATSAPP_MANUAL_RESEND',
      'WhatsAppMessage',
      msg.id,
      {
        recipient: msg.phoneNumber,
        templateName: msg.templateName,
        previousStatus: msg.status,
        newStatus: updated.status,
      },
    );

    return updated;
  }

  // --- Admin Template Registry & Manual Composition ---

  getRegisteredTemplates() {
    return [
      {
        name: 'booking_confirmed',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Sent to customer immediately after booking and deposit escrow are confirmed.',
        requiredVariables: ['customerName', 'bookingId', 'carName', 'pickupDate', 'pickupLocation', 'totalFare'],
        bodySample: 'Hello {{1}}, your booking {{2}} for {{3}} on {{4}} at {{5}} is confirmed! Total: {{6}}.',
      },
      {
        name: 'booking_cancelled',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Sent to customer when a booking is cancelled.',
        requiredVariables: ['customerName', 'bookingId', 'cancellationReason', 'refundAmount'],
        bodySample: 'Hello {{1}}, your booking {{2}} was cancelled (Reason: {{3}}). Refund amount: {{4}}.',
      },
      {
        name: 'payment_successful',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Payment receipt confirmation with transaction ID.',
        requiredVariables: ['customerName', 'bookingId', 'amount', 'paymentId'],
        bodySample: 'Hello {{1}}, payment of {{3}} for booking {{2}} was successful (Txn ID: {{4}}).',
      },
      {
        name: 'refund_processed',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Notification of processed refund to customer original payment method.',
        requiredVariables: ['customerName', 'bookingId', 'refundAmount', 'refundId'],
        bodySample: 'Hello {{1}}, refund of {{3}} for booking {{2}} has been processed (Refund ID: {{4}}).',
      },
      {
        name: 'handover_ready',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Sent when vehicle is cleaned, inspected, and ready for pickup at hub.',
        requiredVariables: ['customerName', 'bookingId', 'carName', 'pickupLocation'],
        bodySample: 'Hello {{1}}, your vehicle {{3}} is ready for pickup at {{4}} for booking {{2}}.',
      },
      {
        name: 'trip_reminder',
        category: 'MARKETING',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Upcoming trip departure reminder 24h prior to pickup.',
        requiredVariables: ['customerName', 'bookingId', 'startDate', 'pickupLocation'],
        bodySample: 'Reminder: Hello {{1}}, your trip for booking {{2}} starts on {{3}} at {{4}}.',
      },
      {
        name: 'emergency_alert',
        category: 'AUTHENTICATION',
        status: 'APPROVED',
        language: 'en_US',
        description: 'SOS Roadside assistance and incident notification to operations.',
        requiredVariables: ['customerName', 'incidentType', 'locationAddress', 'requestNumber'],
        bodySample: 'EMERGENCY: Incident {{2}} reported by {{1}} at {{3}} (Ref: {{4}}).',
      },
      {
        name: 'vendor_booking_alert',
        category: 'UTILITY',
        status: 'APPROVED',
        language: 'en_US',
        description: 'Operational alert to vendor when a new reservation is booked.',
        requiredVariables: ['customerName', 'bookingId', 'carName', 'pickupDate', 'pickupLocation', 'totalFare'],
        bodySample: 'Vendor Alert: New booking {{2}} for {{3}} starting on {{4}} at {{5}}.',
      },
    ];
  }

  async sendManualMessage(
    payload: {
      phoneNumber: string;
      templateName: string;
      variables?: Record<string, any>;
      userId?: string;
      bookingId?: string;
    },
    adminUserId: string,
  ): Promise<WhatsAppMessage> {
    const { phoneNumber, templateName, variables = {}, userId, bookingId } = payload;
    if (!phoneNumber || !templateName) {
      throw new BadRequestException('Recipient phoneNumber and templateName are required.');
    }

    const templates = this.getRegisteredTemplates();
    const tpl = templates.find((t) => t.name === templateName);
    if (!tpl) {
      throw new BadRequestException(`Template '${templateName}' is not registered or supported.`);
    }

    const idempotencyKey = `manual_admin_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    const typeMapping: Record<string, WhatsAppMessageType> = {
      booking_confirmed: WhatsAppMessageType.BOOKING_CONFIRMED,
      booking_cancelled: WhatsAppMessageType.BOOKING_CANCELLED,
      payment_successful: WhatsAppMessageType.PAYMENT_SUCCESSFUL,
      payment_failed: WhatsAppMessageType.PAYMENT_FAILED,
      refund_processed: WhatsAppMessageType.REFUND_PROCESSED,
      handover_ready: WhatsAppMessageType.HANDOVER_READY,
      trip_reminder: WhatsAppMessageType.TRIP_REMINDER,
      emergency_alert: WhatsAppMessageType.EMERGENCY_ALERT,
      vendor_booking_alert: WhatsAppMessageType.BOOKING_CONFIRMED,
    };
    const messageType = typeMapping[templateName] || WhatsAppMessageType.MARKETING_PROMO;

    const message = await this.sendTemplateMessage({
      phoneNumber,
      templateName,
      variables,
      userId,
      bookingId,
      idempotencyKey,
      messageType,
    });

    await this.auditLogService.log(
      adminUserId,
      'WHATSAPP_MANUAL_DISPATCH',
      'WhatsAppMessage',
      message.id,
      {
        recipient: phoneNumber,
        templateName,
        variables,
        userId,
        bookingId,
        status: message.status,
      },
    );

    return message;
  }

  async getMessageTimeline(id: string) {
    const msg = await this.prisma.whatsAppMessage.findUnique({
      where: { id },
    });
    if (!msg) {
      throw new NotFoundException(`WhatsApp message ${id} not found.`);
    }

    const timeline: Array<{ event: string; timestamp: Date; details?: string }> = [
      { event: 'QUEUED', timestamp: msg.createdAt, details: 'Message enqueued in platform outbox' },
    ];

    if (msg.sentAt) {
      timeline.push({
        event: 'SENT',
        timestamp: msg.sentAt,
        details: `Dispatched to Meta Cloud API (Provider ID: ${msg.providerMessageId || 'N/A'})`,
      });
    }

    if (msg.deliveredAt) {
      timeline.push({
        event: 'DELIVERED',
        timestamp: msg.deliveredAt,
        details: 'Delivered to recipient handset (confirmed via webhook)',
      });
    }

    if (msg.readAt) {
      timeline.push({
        event: 'READ',
        timestamp: msg.readAt,
        details: 'Read receipt confirmed by recipient',
      });
    }

    if (msg.failedAt) {
      timeline.push({
        event: 'FAILED',
        timestamp: msg.failedAt,
        details: `${msg.failureCode || 'ERROR'}: ${msg.failureReason || 'Delivery failed'}`,
      });
    }

    return {
      message: msg,
      timeline,
    };
  }
}
