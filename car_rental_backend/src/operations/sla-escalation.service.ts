import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SlaSeverity, BookingStatus, FulfillmentStage } from '@prisma/client';

export interface SlaEvaluationResult {
  totalEvaluated: number;
  breachesDetected: number;
  incidentsCreated: number;
  details: string[];
}

@Injectable()
export class SlaEscalationEngineService {
  private readonly logger = new Logger(SlaEscalationEngineService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Evaluates all operational SLAs across bookings and fulfillment tasks
   */
  async evaluateAllSlas(): Promise<SlaEvaluationResult> {
    const details: string[] = [];
    let breachesDetected = 0;
    let incidentsCreated = 0;

    // 1. Allocation SLA: Confirmed bookings unallocated for > 15 minutes
    const unallocatedBreaches = await this.checkAllocationSla(15);
    breachesDetected += unallocatedBreaches.breaches;
    incidentsCreated += unallocatedBreaches.created;
    details.push(...unallocatedBreaches.details);

    // 2. Preparation SLA: Vehicle not ready < 60 mins before scheduled start
    const prepBreaches = await this.checkPreparationSla(60);
    breachesDetected += prepBreaches.breaches;
    incidentsCreated += prepBreaches.created;
    details.push(...prepBreaches.details);

    // 3. Customer Wait SLA: Customer checked in > 10 mins without handover
    const waitBreaches = await this.checkCustomerWaitSla(10);
    breachesDetected += waitBreaches.breaches;
    incidentsCreated += waitBreaches.created;
    details.push(...waitBreaches.details);

    // 4. Overdue Return SLA: Active rentals > 30 mins past scheduled return
    const overdueBreaches = await this.checkOverdueReturnSla(30);
    breachesDetected += overdueBreaches.breaches;
    incidentsCreated += overdueBreaches.created;
    details.push(...overdueBreaches.details);

    this.logger.log(
      `[SLA-ENGINE] Evaluated SLAs: ${breachesDetected} breaches detected, ${incidentsCreated} new incidents created.`,
    );

    return {
      totalEvaluated: breachesDetected,
      breachesDetected,
      incidentsCreated,
      details,
    };
  }

  // 1. Allocation SLA
  private async checkAllocationSla(thresholdMinutes: number) {
    const threshold = new Date(Date.now() - thresholdMinutes * 60 * 1000);
    const unallocated = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        carId: '', // Or unallocated flag
        createdAt: { lt: threshold },
      },
      take: 25,
    });

    return this.processBreaches(unallocated, 'ALLOCATION', thresholdMinutes, SlaSeverity.WARNING);
  }

  // 2. Preparation SLA
  private async checkPreparationSla(leadMinutes: number) {
    const now = new Date();
    const imminentStart = new Date(now.getTime() + leadMinutes * 60 * 1000);

    const unprepared = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        startDate: { gte: now, lte: imminentStart },
        fulfillmentRecord: {
          stage: {
            notIn: [
              FulfillmentStage.READY_FOR_PICKUP,
              FulfillmentStage.CUSTOMER_CHECKED_IN,
              FulfillmentStage.ACTIVE_RENTAL,
              FulfillmentStage.COMPLETED,
            ],
          },
        },
      },
      include: { fulfillmentRecord: true },
      take: 25,
    });

    return this.processBreaches(unprepared, 'PREPARATION', leadMinutes, SlaSeverity.CRITICAL);
  }

  // 3. Customer Wait SLA
  private async checkCustomerWaitSla(thresholdMinutes: number) {
    const threshold = new Date(Date.now() - thresholdMinutes * 60 * 1000);
    const waitingFulfillments = await this.prisma.fulfillmentRecord.findMany({
      where: {
        stage: FulfillmentStage.CUSTOMER_CHECKED_IN,
        customerCheckedInAt: { lt: threshold },
      },
      include: { booking: true },
      take: 25,
    });

    const bookings = waitingFulfillments.map((f) => f.booking).filter(Boolean);
    const severity = thresholdMinutes >= 20 ? SlaSeverity.CRITICAL : SlaSeverity.WARNING;
    return this.processBreaches(bookings, 'CUSTOMER_WAIT', thresholdMinutes, severity);
  }

  // 4. Overdue Return SLA
  private async checkOverdueReturnSla(thresholdMinutes: number) {
    const threshold = new Date(Date.now() - thresholdMinutes * 60 * 1000);
    const overdueBookings = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.ONGOING,
        endDate: { lt: threshold },
      },
      take: 25,
    });

    return this.processBreaches(overdueBookings, 'OVERDUE_RETURN', thresholdMinutes, SlaSeverity.CRITICAL);
  }

  // Common breach recorder
  private async processBreaches(
    bookings: any[],
    targetProcess: string,
    thresholdMinutes: number,
    severity: SlaSeverity,
  ) {
    let breaches = 0;
    let created = 0;
    const details: string[] = [];

    // Ensure policy exists
    let policy = await this.prisma.slaPolicyDefinition.findFirst({
      where: { targetProcess, isActive: true },
    });

    if (!policy) {
      policy = await this.prisma.slaPolicyDefinition.create({
        data: {
          targetProcess,
          thresholdMinutes,
          severity,
          action: 'ALERT_AND_TASK',
        },
      });
    }

    for (const b of bookings) {
      breaches++;
      const existing = await this.prisma.slaBreachIncident.findFirst({
        where: {
          bookingId: b.id,
          targetProcess,
          status: 'OPEN',
        },
      });

      if (!existing) {
        created++;
        const elapsed = Math.round((Date.now() - b.updatedAt.getTime()) / (60 * 1000));
        await this.prisma.slaBreachIncident.create({
          data: {
            policyId: policy.id,
            bookingId: b.id,
            vendorId: b.vendorId,
            branchId: b.pickupHubId,
            targetProcess,
            severity,
            thresholdMinutes,
            elapsedMinutes: Math.max(thresholdMinutes, elapsed),
            status: 'OPEN',
          },
        });
        details.push(`SLA Breach: ${targetProcess} for Booking #${b.id} (${severity})`);
      }
    }

    return { breaches, created, details };
  }
}
