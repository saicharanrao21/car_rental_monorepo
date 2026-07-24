import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarsQueryDto, SortByOption } from './dto/cars-query.dto';
import { CreateCarDto } from './dto/create-car.dto';
import { UpdateCarDto } from './dto/update-car.dto';
import { AdminCarsQueryDto } from './dto/admin-cars-query.dto';
import { PaginatedResult } from '../common/pagination.dto';

import { redactVendor } from '../common/vendor-redactor.util';

@Injectable()
export class CarsService {
  constructor(private readonly prisma: PrismaService) {}

  // --- Reusable Ownership Validation ---
  async verifyOwnership(carId: string, userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const car = await this.prisma.car.findUnique({
      where: { id: carId },
    });
    if (!car) {
      throw new NotFoundException('Car not found');
    }

    if (car.vendorId !== vendor.id) {
      throw new ForbiddenException('Access denied: You do not own this car.');
    }

    return { car, vendor };
  }

  async searchCars(query: CarsQueryDto, isAdmin: boolean): Promise<PaginatedResult<any>> {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: any = {
      vendor: {
        city: { equals: query.city, mode: 'insensitive' },
      },
    };

    // By default, non-admins only see available cars
    if (!isAdmin) {
      where.isAvailable = true;
    }

    if (query.carType) {
      where.type = query.carType;
    }

    if (query.isAC !== undefined) {
      where.isAC = query.isAC;
    }

    if (query.minPrice !== undefined || query.maxPrice !== undefined) {
      where.pricePerDay = {};
      if (query.minPrice !== undefined) {
        where.pricePerDay.gte = query.minPrice;
      }
      if (query.maxPrice !== undefined) {
        where.pricePerDay.lte = query.maxPrice;
      }
    }

    if (query.minRating !== undefined) {
      where.vendor.rating = { gte: query.minRating };
    }

    if (query.tripType) {
      where.availableTripTypes = { has: query.tripType };
    }

    // Build sort ordering
    let orderBy: any = { createdAt: 'desc' }; // Default RELEVANCE
    if (query.sortBy === SortByOption.PRICE_ASC) {
      orderBy = { pricePerDay: 'asc' };
    } else if (query.sortBy === SortByOption.PRICE_DESC) {
      orderBy = { pricePerDay: 'desc' };
    } else if (query.sortBy === SortByOption.RATING) {
      orderBy = { vendor: { rating: 'desc' } };
    }

    const [total, data] = await Promise.all([
      this.prisma.car.count({ where }),
      this.prisma.car.findMany({
        where,
        skip,
        take: limit,
        orderBy,
        include: {
          vendor: {
            select: {
              id: true,
              businessName: true,
              ownerName: true,
              city: true,
              locality: true,
              rating: true,
              latitude: true,
              longitude: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(total / limit);
    const redactedData = data.map((car) => ({
      ...car,
      vendor: redactVendor(car.vendor, { isAdmin }),
    }));

    return {
      data: redactedData,
      total,
      page,
      totalPages,
    };
  }

  async findOne(id: string) {
    const car = await this.prisma.car.findUnique({
      where: { id },
      include: {
        vendor: {
          select: {
            id: true,
            businessName: true,
            ownerName: true,
            city: true,
            locality: true,
            rating: true,
            latitude: true,
            longitude: true,
          },
        },
      },
    });

    if (!car) {
      throw new NotFoundException('Car not found');
    }

    return {
      ...car,
      vendor: redactVendor(car.vendor, { isAdmin: false }),
    };
  }

  async findVendorCars(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    return this.prisma.car.findMany({
      where: { vendorId: vendor.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createCar(userId: string, dto: CreateCarDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    return this.prisma.car.create({
      data: {
        vendorId: vendor.id,
        make: dto.make,
        model: dto.model,
        year: dto.year,
        type: dto.type,
        fuelType: dto.fuelType,
        seating: dto.seating,
        isAC: dto.isAC,
        registrationNumber: dto.registrationNumber,
        photos: dto.photos || [],
        pricePerKm: dto.pricePerKm,
        pricePerDay: dto.pricePerDay,
        pricePerHour: dto.pricePerHour,
        isAvailable: dto.isAvailable !== undefined ? dto.isAvailable : true,
        availableTripTypes: dto.availableTripTypes || [],
      },
    });
  }

  async updateCar(carId: string, userId: string, dto: UpdateCarDto) {
    await this.verifyOwnership(carId, userId);

    return this.prisma.car.update({
      where: { id: carId },
      data: {
        make: dto.make ?? undefined,
        model: dto.model ?? undefined,
        year: dto.year ?? undefined,
        type: dto.type ?? undefined,
        fuelType: dto.fuelType ?? undefined,
        seating: dto.seating ?? undefined,
        isAC: dto.isAC ?? undefined,
        registrationNumber: dto.registrationNumber ?? undefined,
        photos: dto.photos ?? undefined,
        pricePerKm: dto.pricePerKm ?? undefined,
        pricePerDay: dto.pricePerDay ?? undefined,
        pricePerHour: dto.pricePerHour ?? undefined,
        availableTripTypes: dto.availableTripTypes ?? undefined,
      },
    });
  }

  async updateAvailability(carId: string, userId: string, isAvailable: boolean) {
    await this.verifyOwnership(carId, userId);

    return this.prisma.car.update({
      where: { id: carId },
      data: { isAvailable },
    });
  }

  async updateBlockedDates(carId: string, userId: string, blockedDates: string[]) {
    await this.verifyOwnership(carId, userId);

    const dates = blockedDates.map((d) => new Date(d));

    return this.prisma.car.update({
      where: { id: carId },
      data: { blockedDates: dates },
    });
  }

  async adminFindAll(query: AdminCarsQueryDto): Promise<PaginatedResult<any>> {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: any = {};

    if (query.city) {
      where.vendor = {
        city: { equals: query.city, mode: 'insensitive' },
      };
    }

    if (query.carType) {
      where.type = query.carType;
    }

    if (query.isAvailable !== undefined) {
      where.isAvailable = query.isAvailable;
    }

    if (query.vendorId) {
      where.vendorId = query.vendorId;
    }

    const [total, data] = await Promise.all([
      this.prisma.car.count({ where }),
      this.prisma.car.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          vendor: {
            select: {
              id: true,
              businessName: true,
              ownerName: true,
              city: true,
              rating: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(total / limit);

    return {
      data,
      total,
      page,
      totalPages,
    };
  }

  async adminDeactivate(id: string) {
    const car = await this.prisma.car.findUnique({
      where: { id },
    });

    if (!car) {
      throw new NotFoundException('Car not found');
    }

    return this.prisma.car.update({
      where: { id },
      data: { isAvailable: false },
    });
  }
}
