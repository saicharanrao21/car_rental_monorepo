import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { redactVendor } from '../common/vendor-redactor.util';

@Injectable()
export class RecentlyViewedService {
  constructor(private readonly prisma: PrismaService) {}

  async recordView(userId: string, carId: string) {
    const car = await this.prisma.car.findUnique({ where: { id: carId } });
    if (!car) {
      throw new NotFoundException('Car not found');
    }

    const existing = await this.prisma.recentlyViewed.findFirst({
      where: {
        userId,
        carId,
      },
    });

    if (existing) {
      return this.prisma.recentlyViewed.update({
        where: { id: existing.id },
        data: { viewedAt: new Date() },
      });
    }

    return this.prisma.recentlyViewed.create({
      data: {
        userId,
        carId,
        viewedAt: new Date(),
      },
    });
  }

  async getMyRecentlyViewed(userId: string) {
    const items = await this.prisma.recentlyViewed.findMany({
      where: { userId },
      take: 10,
      orderBy: { viewedAt: 'desc' },
      include: {
        car: {
          include: {
            vendor: true,
          },
        },
      },
    });

    return items.map((item) => ({
      ...item.car,
      viewedAt: item.viewedAt,
      vendor: redactVendor(item.car.vendor, { isAdmin: false }),
    }));
  }
}
