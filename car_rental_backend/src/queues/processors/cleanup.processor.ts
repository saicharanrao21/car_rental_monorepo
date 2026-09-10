import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { Job } from 'bullmq';
import { QueueFactoryService } from '../queue-factory.service';
import { QUEUE_NAMES, JOB_TYPES } from '../queue.constants';
import { PrismaService } from '../../prisma/prisma.service';
import { RentalAutomationService } from '../../bookings/rental-automation.service';

@Injectable()
export class CleanupProcessor implements OnModuleInit {
  private readonly logger = new Logger(CleanupProcessor.name);
  private rentalAutomation?: RentalAutomationService;

  constructor(
    private readonly queueFactory: QueueFactoryService,
    private readonly prisma: PrismaService,
    private readonly moduleRef: ModuleRef,
  ) {}

  onModuleInit() {
    this.queueFactory.registerWorker(
      QUEUE_NAMES.CLEANUP,
      this.process.bind(this),
      1, // Single concurrency for cleanup jobs
    );
  }

  private getRentalAutomation(): RentalAutomationService | null {
    if (!this.rentalAutomation) {
      try {
        this.rentalAutomation = this.moduleRef.get(RentalAutomationService, {
          strict: false,
        });
      } catch {
        this.rentalAutomation = undefined;
      }
    }
    return this.rentalAutomation || null;
  }

  async process(job: Job): Promise<any> {
    this.logger.log(`[PROCESS_CLEANUP] Job ${job.id} task: ${job.name}`);

    if (
      job.name === JOB_TYPES.CLEANUP.PURGE_EXPIRED_OTPS ||
      job.name === 'purge-expired-otps' ||
      job.data?.task === 'PURGE_EXPIRED_OTPS'
    ) {
      const deleted = await this.prisma.otpRequest.deleteMany({
        where: {
          expiresAt: { lt: new Date(Date.now() - 3600 * 1000) }, // Expired over 1 hour ago
        },
      });
      this.logger.log(`[CLEANUP_OTP] Purged ${deleted.count} expired OTP records`);
      return { purgedOtps: deleted.count };
    }

    if (
      job.name === JOB_TYPES.CLEANUP.EXPIRE_STALE_BOOKINGS ||
      job.name === 'expire-stale-bookings' ||
      job.data?.task === 'EXPIRE_STALE_BOOKINGS'
    ) {
      const rentalAutomation = this.getRentalAutomation();
      if (rentalAutomation) {
        const timeoutMinutes = job.data?.timeoutMinutes || 30;
        const res = await rentalAutomation.expireUnconfirmedReservations(timeoutMinutes);
        const holdsRes = await rentalAutomation.expireStaleVehicleHolds();
        this.logger.log(
          `[CLEANUP_BOOKINGS] Expired ${res.successCount} stale bookings and ${holdsRes.successCount} stale holds`,
        );
        return {
          expiredBookings: res.successCount,
          expiredHolds: holdsRes.successCount,
          details: res.details,
        };
      }

      // Direct fallback using Prisma if service not injected
      const timeoutMinutes = job.data?.timeoutMinutes || 30;
      const threshold = new Date(Date.now() - timeoutMinutes * 60 * 1000);
      const staleBookings = await this.prisma.booking.findMany({
        where: {
          status: 'PENDING' as any,
          createdAt: { lt: threshold },
        },
        select: { id: true },
        take: 50,
      });

      let updatedCount = 0;
      for (const b of staleBookings) {
        await this.prisma.booking.update({
          where: { id: b.id },
          data: {
            status: 'EXPIRED' as any,
            cancellationReason: `Booking automatically expired after ${timeoutMinutes} minutes without confirmation.`,
            cancelledAt: new Date(),
            cancelledBy: 'SYSTEM',
          },
        });
        updatedCount++;
      }
      this.logger.log(`[CLEANUP_BOOKINGS] Direct sweep expired ${updatedCount} stale bookings`);
      return { expiredBookings: updatedCount };
    }

    if (
      job.name === JOB_TYPES.CLEANUP.CLEAN_TEMP_STORAGE ||
      job.name === 'clean-temp-storage' ||
      job.data?.task === 'CLEAN_TEMP_STORAGE'
    ) {
      this.logger.log(`[CLEANUP_STORAGE] Temp storage cleanup completed`);
      return { status: 'CLEANED' };
    }

    this.logger.warn(`[CLEANUP_UNKNOWN] Unknown cleanup task: ${job.name}`);
    return { status: 'IGNORED' };
  }
}

