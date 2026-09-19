import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export class JoinWaitlistDto {
  carId?: string;
  city!: string;
  carCategory?: string;
  startDate!: string | Date;
  endDate!: string | Date;
  notes?: string;
}

@Injectable()
export class WaitlistService {
  constructor(private readonly prisma: PrismaService) {}

  async joinWaitlist(customerId: string, dto: JoinWaitlistDto) {
    if (!customerId) {
      throw new BadRequestException('customerId is required');
    }
    if (!dto.city) {
      throw new BadRequestException('city is required');
    }

    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid startDate or endDate format');
    }

    if (end <= start) {
      throw new BadRequestException('endDate must be after startDate');
    }

    // Check for existing active waitlist entry for the same user, car, and overlapping window
    const existing = await this.prisma.waitlistEntry.findFirst({
      where: {
        customerId,
        carId: dto.carId || null,
        city: dto.city,
        status: 'ACTIVE',
        startDate: { lte: end },
        endDate: { gte: start },
      },
    });

    if (existing) {
      throw new ConflictException('You already have an active waitlist entry for this vehicle and timeframe');
    }

    return this.prisma.waitlistEntry.create({
      data: {
        customerId,
        carId: dto.carId || null,
        city: dto.city,
        carCategory: dto.carCategory || null,
        startDate: start,
        endDate: end,
        notes: dto.notes || null,
        status: 'ACTIVE',
      },
      include: {
        car: {
          select: {
            id: true,
            make: true,
            model: true,
            year: true,
            photos: true,
            pricePerDay: true,
          },
        },
      },
    });
  }

  async getUserWaitlist(customerId: string) {
    return this.prisma.waitlistEntry.findMany({
      where: { customerId },
      orderBy: { createdAt: 'desc' },
      include: {
        car: {
          select: {
            id: true,
            make: true,
            model: true,
            year: true,
            photos: true,
            pricePerDay: true,
          },
        },
      },
    });
  }

  async cancelWaitlistEntry(entryId: string, customerId: string) {
    const entry = await this.prisma.waitlistEntry.findUnique({
      where: { id: entryId },
    });

    if (!entry) {
      throw new NotFoundException(`Waitlist entry ${entryId} not found`);
    }

    if (entry.customerId !== customerId) {
      throw new BadRequestException('Not authorized to cancel this waitlist entry');
    }

    return this.prisma.waitlistEntry.update({
      where: { id: entryId },
      data: { status: 'CANCELLED' },
    });
  }

  async notifyWaitlistEntry(entryId: string) {
    const entry = await this.prisma.waitlistEntry.findUnique({
      where: { id: entryId },
    });

    if (!entry) {
      throw new NotFoundException(`Waitlist entry ${entryId} not found`);
    }

    return this.prisma.waitlistEntry.update({
      where: { id: entryId },
      data: {
        status: 'NOTIFIED',
        notifiedAt: new Date(),
      },
    });
  }

  async listWaitlistAdmin(city?: string, status?: string) {
    const where: any = {};
    if (city) where.city = city;
    if (status) where.status = status;

    return this.prisma.waitlistEntry.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        car: { select: { id: true, make: true, model: true, registrationNumber: true } },
      },
    });
  }
}
