import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { BookingStatus, QuoteStatus, Role, VehicleHoldStatus } from '@prisma/client';
import { Cron, CronExpression } from '@nestjs/schedule';
import { SlaEscalationEngineService } from '../operations/sla-escalation.service';

export interface AutomationRunResult {
  jobName: string;
  processedCount: number;
  successCount: number;
  failedCount: number;
  details: string[];
}

@Injectable()
export class RentalAutomationService {
  private readonly logger = new Logger(RentalAutomationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookingLifecycle: BookingLifecycleService,
    @Optional() private readonly slaEngine?: SlaEscalationEngineService,
  ) {}

  /**
   * 1. Expire stale booking quotes whose 15-minute TTL has elapsed.
   */
  async expireStaleQuotes(): Promise<AutomationRunResult> {
    const now = new Date();
    const staleQuotes = await this.prisma.bookingQuote.findMany({
      where: {
        status: QuoteStatus.ACTIVE,
        expiresAt: { lt: now },
      },
      take: 100,
    });

    let successCount = 0;
    const details: string[] = [];

    for (const q of staleQuotes) {
      try {
        await this.prisma.bookingQuote.update({
          where: { id: q.id },
          data: { status: QuoteStatus.EXPIRED },
        });
        successCount++;
        details.push(`Quote #${q.id} marked EXPIRED`);
      } catch (err: any) {
        this.logger.warn(`Failed to expire quote #${q.id}: ${err.message}`);
      }
    }

    this.logger.log(`[AUTOMATION] Expired ${successCount}/${staleQuotes.length} stale booking quotes.`);

    return {
      jobName: 'EXPIRE_STALE_QUOTES',
      processedCount: staleQuotes.length,
      successCount,
      failedCount: staleQuotes.length - successCount,
      details,
    };
  }

  /**
   * 2. Expire unconfirmed pending bookings exceeding timeout window (e.g. 30 mins).
   */
  async expireUnconfirmedReservations(timeoutMinutes = 30): Promise<AutomationRunResult> {
    const threshold = new Date(Date.now() - timeoutMinutes * 60 * 1000);
    const unconfirmed = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.PENDING,
        createdAt: { lt: threshold },
      },
      take: 50,
    });

    let successCount = 0;
    const details: string[] = [];

    for (const b of unconfirmed) {
      try {
        await this.bookingLifecycle.expireBooking(
          b.id,
          `Booking automatically expired after ${timeoutMinutes} minutes without confirmation.`,
        );
        successCount++;
        details.push(`Booking #${b.id} expired`);
      } catch (err: any) {
        this.logger.warn(`Failed to auto-expire booking #${b.id}: ${err.message}`);
      }
    }

    this.logger.log(`[AUTOMATION] Expired ${successCount}/${unconfirmed.length} unconfirmed reservations.`);

    return {
      jobName: 'EXPIRE_UNCONFIRMED_RESERVATIONS',
      processedCount: unconfirmed.length,
      successCount,
      failedCount: unconfirmed.length - successCount,
      details,
    };
  }

  /**
   * 3. Detect overdue rentals returning past scheduled return time + grace period (45m).
   */
  async detectOverdueReturns(graceMinutes = 45): Promise<AutomationRunResult> {
    const threshold = new Date(Date.now() - graceMinutes * 60 * 1000);
    const overdueTrips = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.ONGOING,
        endDate: { lt: threshold },
      },
      include: {
        customer: true,
        vendor: true,
        car: true,
      },
      take: 50,
    });

    let successCount = 0;
    const details: string[] = [];

    for (const trip of overdueTrips) {
      try {
        const lateMinutes = Math.round((Date.now() - trip.endDate.getTime()) / (60 * 1000));
        // Check if overdue event already recorded recently
        const existingAlert = await this.prisma.bookingOutboxEvent.findFirst({
          where: {
            bookingId: trip.id,
            eventType: 'RENTAL_OVERDUE_ALERT',
            createdAt: { gt: new Date(Date.now() - 4 * 60 * 60 * 1000) }, // within 4 hours
          },
        });

        if (!existingAlert) {
          await this.prisma.bookingOutboxEvent.create({
            data: {
              bookingId: trip.id,
              aggregateId: trip.id,
              tenantId: trip.vendorId,
              eventType: 'RENTAL_OVERDUE_ALERT',
              correlationId: `alert_overdue_${trip.id}_${Date.now()}`,
              actorId: 'SYSTEM',
              actorRole: 'SYSTEM',
              previousStatus: BookingStatus.ONGOING,
              newStatus: BookingStatus.ONGOING,
              payload: {
                bookingId: trip.id,
                customerId: trip.customerId,
                vendorId: trip.vendorId,
                carRegistration: trip.car.registrationNumber,
                scheduledEnd: trip.endDate.toISOString(),
                lateMinutes,
                alertLevel: lateMinutes > 180 ? 'CRITICAL' : 'WARNING',
              },
            },
          });
          details.push(`Alerted overdue trip #${trip.id} (${lateMinutes}m late)`);
        }
        successCount++;
      } catch (err: any) {
        this.logger.warn(`Failed to process overdue trip #${trip.id}: ${err.message}`);
      }
    }

    this.logger.log(`[AUTOMATION] Detected ${overdueTrips.length} overdue rentals.`);

    return {
      jobName: 'DETECT_OVERDUE_RETURNS',
      processedCount: overdueTrips.length,
      successCount,
      failedCount: overdueTrips.length - successCount,
      details,
    };
  }

  /**
   * 4. Enqueue upcoming pickup reminders (24h and 2h before trip start).
   */
  async processPickupReminders(): Promise<AutomationRunResult> {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in2h = new Date(now.getTime() + 2 * 60 * 60 * 1000);

    const upcoming = await this.prisma.booking.findMany({
      where: {
        status: { in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY] },
        startDate: { gte: now, lte: in24h },
      },
      include: { customer: true, car: true, vendor: true },
      take: 50,
    });

    let successCount = 0;
    const details: string[] = [];

    for (const b of upcoming) {
      try {
        const isImminent = b.startDate <= in2h;
        const reminderType = isImminent ? 'PICKUP_REMINDER_2H' : 'PICKUP_REMINDER_24H';

        const alreadySent = await this.prisma.bookingOutboxEvent.findFirst({
          where: {
            bookingId: b.id,
            eventType: reminderType,
          },
        });

        if (!alreadySent) {
          await this.prisma.bookingOutboxEvent.create({
            data: {
              bookingId: b.id,
              aggregateId: b.id,
              tenantId: b.vendorId,
              eventType: reminderType,
              correlationId: `reminder_${reminderType.toLowerCase()}_${b.id}`,
              actorId: 'SYSTEM',
              actorRole: 'SYSTEM',
              previousStatus: b.status,
              newStatus: b.status,
              payload: {
                bookingId: b.id,
                customerId: b.customerId,
                customerPhone: b.customer.phone,
                vehicleName: `${b.car.make} ${b.car.model}`,
                startDate: b.startDate.toISOString(),
                pickupLocation: b.pickupLocation,
              },
            },
          });
          details.push(`Enqueued ${reminderType} for #${b.id}`);
        }
        successCount++;
      } catch (err: any) {
        this.logger.warn(`Failed to process reminder for #${b.id}: ${err.message}`);
      }
    }

    return {
      jobName: 'PROCESS_PICKUP_REMINDERS',
      processedCount: upcoming.length,
      successCount,
      failedCount: upcoming.length - successCount,
      details,
    };
  }

  /**
   * 5. Expire stale temporary vehicle holds where checkout was abandoned.
   */
  async expireStaleVehicleHolds(): Promise<AutomationRunResult> {
    const now = new Date();
    const staleHolds = await this.prisma.vehicleHold.findMany({
      where: {
        status: VehicleHoldStatus.ACTIVE,
        expiresAt: { lt: now },
      },
      take: 100,
    });

    let successCount = 0;
    const details: string[] = [];

    for (const hold of staleHolds) {
      try {
        await this.prisma.vehicleHold.update({
          where: { id: hold.id },
          data: { status: VehicleHoldStatus.EXPIRED },
        });
        successCount++;
        details.push(`Hold #${hold.id} on Car #${hold.carId} marked EXPIRED`);
      } catch (err: any) {
        this.logger.warn(`Failed to expire hold #${hold.id}: ${err.message}`);
      }
    }

    this.logger.log(`[AUTOMATION] Expired ${successCount}/${staleHolds.length} stale vehicle holds.`);

    return {
      jobName: 'EXPIRE_STALE_VEHICLE_HOLDS',
      processedCount: staleHolds.length,
      successCount,
      failedCount: staleHolds.length - successCount,
      details,
    };
  }

  /**
   * 6. Evaluate operational SLA policies across bookings and fulfillment records.
   */
  async evaluateOperationalSlas(): Promise<AutomationRunResult> {
    if (!this.slaEngine) {
      return {
        jobName: 'EVALUATE_OPERATIONAL_SLAS',
        processedCount: 0,
        successCount: 0,
        failedCount: 0,
        details: ['SlaEscalationEngineService not injected'],
      };
    }

    const res = await this.slaEngine.evaluateAllSlas();
    return {
      jobName: 'EVALUATE_OPERATIONAL_SLAS',
      processedCount: res.totalEvaluated,
      successCount: res.incidentsCreated,
      failedCount: 0,
      details: res.details,
    };
  }

  /**
   * Periodic Automated Maintenance Sweep running every 5 minutes.
   */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async runScheduledAutomationCycle() {
    this.logger.log('[AUTOMATION] Starting 5-minute automated maintenance sweep...');
    await Promise.allSettled([
      this.expireStaleQuotes(),
      this.expireUnconfirmedReservations(),
      this.expireStaleVehicleHolds(),
      this.detectOverdueReturns(),
      this.processPickupReminders(),
      this.evaluateOperationalSlas(),
    ]);
    this.logger.log('[AUTOMATION] 5-minute automated maintenance sweep completed.');
  }
}
