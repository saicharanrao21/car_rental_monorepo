import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationOrchestratorService } from '../notifications/notification-orchestrator.service';
import { NotificationRealtimeService } from '../notifications/notification-realtime.service';
import { OperationalEventType } from '../notifications/templates/notification-templates';
import { BookingLifecyclePayload } from './booking-lifecycle.types';

@Injectable()
export class BookingOutboxService {
  private readonly logger = new Logger(BookingOutboxService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly notificationOrchestrator?: NotificationOrchestratorService,
    @Optional() private readonly realtimeService?: NotificationRealtimeService,
  ) {}

  /**
   * Dispatches a persistent outbox event to downstream notification orchestrator and real-time SSE stream.
   * Guarantees at-least-once delivery with duplicate suppression via deterministic correlationId.
   */
  async dispatchEvent(outboxEventId: string): Promise<boolean> {
    const event = await this.prisma.bookingOutboxEvent.findUnique({
      where: { id: outboxEventId },
    });

    if (!event) {
      this.logger.warn(`Outbox event ${outboxEventId} not found for dispatch.`);
      return false;
    }

    if (event.status === 'PUBLISHED') {
      this.logger.debug(`Outbox event ${outboxEventId} already PUBLISHED (idempotent skip).`);
      return true;
    }

    const payload = event.payload as unknown as BookingLifecyclePayload;

    try {
      // 1. Emit live real-time update to Customer & Vendor via SSE
      if (this.realtimeService) {
        if (payload.customerId) {
          this.realtimeService.emitEvent({
            type: 'NOTIFICATION',
            userId: payload.customerId,
            timestamp: new Date().toISOString(),
            notification: {
              id: `notif_${event.correlationId}_cust`,
              userId: payload.customerId,
              title: this.getEventTitle(event.eventType, payload),
              body: this.getEventBody(event.eventType, payload, 'CUSTOMER'),
              category: 'BOOKING',
              eventType: event.eventType,
              entityType: 'BOOKING',
              entityId: event.bookingId,
              priority: event.eventType === 'HANDOVER_READY' ? 'HIGH' : 'NORMAL',
              isRead: false,
              actionUrl: `/my-bookings/${event.bookingId}`,
              createdAt: new Date().toISOString(),
            },
          });
        }

        // Also emit to vendor if vendor user is bound
        const vendor = await this.prisma.vendor.findUnique({
          where: { id: event.tenantId },
          select: { userId: true },
        });

        if (vendor && vendor.userId) {
          this.realtimeService.emitEvent({
            type: 'NOTIFICATION',
            userId: vendor.userId,
            timestamp: new Date().toISOString(),
            notification: {
              id: `notif_${event.correlationId}_vnd`,
              userId: vendor.userId,
              title: this.getEventTitle(event.eventType, payload),
              body: this.getEventBody(event.eventType, payload, 'VENDOR'),
              category: 'BOOKING',
              eventType: event.eventType,
              entityType: 'BOOKING',
              entityId: event.bookingId,
              priority: 'NORMAL',
              isRead: false,
              actionUrl: `/vendor/bookings/${event.bookingId}`,
              createdAt: new Date().toISOString(),
            },
          });
        }
      }

      // 2. Publish through NotificationOrchestratorService for multi-channel SMS, Push, WhatsApp & Email
      if (this.notificationOrchestrator) {
        const operationalType = this.mapToOperationalEventType(event.eventType);

        // Notify Customer
        if (payload.customerId) {
          await this.notificationOrchestrator.publishEvent({
            eventType: operationalType,
            recipientId: payload.customerId,
            entityType: 'BOOKING',
            entityId: event.bookingId,
            variables: {
              customerName: payload.customerName,
              vendorName: payload.vendorName,
              bookingId: event.bookingId,
              vehicleName: payload.vehicleName,
              registrationNumber: payload.registrationNumber,
              pickupTime: payload.startDate,
              returnTime: payload.endDate,
              pickupAddress: payload.pickupLocation,
              returnAddress: payload.dropLocation || payload.pickupLocation,
              paymentAmount: payload.totalFare,
              refundAmount: payload.refundAmount,
              reason: payload.cancellationReason,
              actionUrl: `/my-bookings/${event.bookingId}`,
            },
          });
        }

        // Notify Vendor for milestone events
        if (
          event.eventType === 'BOOKING_CREATED' ||
          event.eventType === 'BOOKING_CANCELLED' ||
          event.eventType === 'RETURN_PENDING' ||
          event.eventType === 'BOOKING_COMPLETED'
        ) {
          const vendor = await this.prisma.vendor.findUnique({
            where: { id: event.tenantId },
            select: { userId: true, businessName: true },
          });

          if (vendor && vendor.userId) {
            await this.notificationOrchestrator.publishEvent({
              eventType: operationalType,
              recipientId: vendor.userId,
              entityType: 'BOOKING',
              entityId: event.bookingId,
              variables: {
                customerName: payload.customerName,
                vendorName: vendor.businessName,
                bookingId: event.bookingId,
                vehicleName: payload.vehicleName,
                registrationNumber: payload.registrationNumber,
                pickupTime: payload.startDate,
                returnTime: payload.endDate,
                paymentAmount: payload.totalFare,
                reason: payload.cancellationReason,
                actionUrl: `/vendor/bookings/${event.bookingId}`,
              },
            });
          }
        }
      }

      // 3. Mark outbox event as PUBLISHED
      await this.prisma.bookingOutboxEvent.update({
        where: { id: outboxEventId },
        data: {
          status: 'PUBLISHED',
          processedAt: new Date(),
          lastError: null,
        },
      });

      this.logger.log(`Outbox event ${outboxEventId} (${event.eventType}) successfully published.`);
      return true;
    } catch (err: any) {
      const nextRetryCount = event.retryCount + 1;
      const isDeadLetter = nextRetryCount >= event.maxRetries;
      const newStatus = isDeadLetter ? 'DEAD_LETTER' : 'FAILED';

      this.logger.error(
        `Failed to dispatch outbox event ${outboxEventId} (Attempt ${nextRetryCount}/${event.maxRetries}): ${err?.message}`,
        err?.stack,
      );

      await this.prisma.bookingOutboxEvent.update({
        where: { id: outboxEventId },
        data: {
          status: newStatus,
          retryCount: nextRetryCount,
          lastError: err?.message || String(err),
        },
      });

      return false;
    }
  }

  /**
   * Retrieves chronological lifecycle history for a booking.
   */
  async getLifecycleHistory(bookingId: string) {
    return this.prisma.bookingOutboxEvent.findMany({
      where: { bookingId },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Maps internal lifecycle event to template engine OperationalEventType.
   */
  private mapToOperationalEventType(eventType: string): OperationalEventType {
    switch (eventType) {
      case 'BOOKING_CREATED':
        return 'BOOKING_CREATED';
      case 'BOOKING_CONFIRMED':
        return 'BOOKING_CONFIRMED';
      case 'BOOKING_CANCELLED':
        return 'BOOKING_CANCELLED';
      case 'HANDOVER_READY':
        return 'HANDOVER_READY';
      case 'TRIP_STARTED':
        return 'TRIP_STARTED';
      case 'RETURN_PENDING':
        return 'RETURN_PENDING';
      case 'BOOKING_COMPLETED':
        return 'BOOKING_COMPLETED';
      default:
        return 'BOOKING_CONFIRMED';
    }
  }

  private getEventTitle(eventType: string, payload: BookingLifecyclePayload): string {
    switch (eventType) {
      case 'BOOKING_CREATED':
        return 'New Booking Created';
      case 'BOOKING_CONFIRMED':
        return 'Booking Confirmed';
      case 'BOOKING_CANCELLED':
        return 'Booking Cancelled';
      case 'HANDOVER_READY':
        return 'Vehicle Ready for Handover';
      case 'TRIP_STARTED':
        return 'Trip In Progress';
      case 'RETURN_PENDING':
        return 'Vehicle Return Initiated';
      case 'BOOKING_COMPLETED':
        return 'Trip Completed';
      case 'BOOKING_EXPIRED':
        return 'Booking Expired';
      default:
        return 'Booking State Updated';
    }
  }

  private getEventBody(eventType: string, payload: BookingLifecyclePayload, recipientRole: 'CUSTOMER' | 'VENDOR'): string {
    const vehicle = `${payload.vehicleName} (${payload.registrationNumber})`;
    switch (eventType) {
      case 'BOOKING_CREATED':
        return recipientRole === 'CUSTOMER'
          ? `Your booking request for ${vehicle} has been received.`
          : `New booking request received for ${vehicle}. Please review and accept.`;
      case 'BOOKING_CONFIRMED':
        return recipientRole === 'CUSTOMER'
          ? `Your booking for ${vehicle} has been accepted by the host.`
          : `You confirmed the booking for ${vehicle}.`;
      case 'BOOKING_CANCELLED':
        return `Booking for ${vehicle} was cancelled. ${payload.cancellationReason ? `Reason: ${payload.cancellationReason}` : ''}`;
      case 'HANDOVER_READY':
        return `Pre-trip inspection finalized for ${vehicle}. Vehicle is ready at hub.`;
      case 'TRIP_STARTED':
        return `Pickup OTP verified. Handover complete and trip has officially started for ${vehicle}.`;
      case 'RETURN_PENDING':
        return `Vehicle return process initiated for ${vehicle}. Post-trip inspection pending.`;
      case 'BOOKING_COMPLETED':
        return `Trip concluded cleanly for ${vehicle}. Escrow quarantine lifted and security deposit reconciled.`;
      case 'BOOKING_EXPIRED':
        return `Booking for ${vehicle} expired due to unconfirmed timeout.`;
      default:
        return `Booking for ${vehicle} is now in ${eventType}.`;
    }
  }
}
