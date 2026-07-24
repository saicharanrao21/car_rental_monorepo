import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { redactVendor } from '../common/vendor-redactor.util';
import { PaginationDto } from '../common/pagination.dto';

@Injectable()
export class WishlistService {
  constructor(private readonly prisma: PrismaService) {}

  async toggleWishlist(userId: string, carId: string) {
    const car = await this.prisma.car.findUnique({ where: { id: carId } });
    if (!car) {
      throw new NotFoundException('Car not found');
    }

    const existing = await this.prisma.wishlist.findUnique({
      where: {
        userId_carId: {
          userId,
          carId,
        },
      },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.wishlist.create({
      data: {
        userId,
        carId,
      },
    });
  }

  async removeFromWishlist(userId: string, carId: string) {
    await this.prisma.wishlist.deleteMany({
      where: {
        userId,
        carId,
      },
    });
    return { success: true };
  }

  async getMyWishlist(userId: string, pagination: PaginationDto) {
    const page = pagination?.page || 1;
    const limit = pagination?.limit || 10;
    const skip = (page - 1) * limit;

    const [total, wishlists] = await Promise.all([
      this.prisma.wishlist.count({ where: { userId } }),
      this.prisma.wishlist.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          car: {
            include: {
              vendor: true,
            },
          },
        },
      }),
    ]);

    const data = wishlists.map((w) => ({
      ...w.car,
      vendor: redactVendor(w.car.vendor, { isAdmin: false }),
    }));

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }
}
