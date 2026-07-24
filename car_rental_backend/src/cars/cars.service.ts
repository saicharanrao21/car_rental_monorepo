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

  private calculateHaversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Earth's radius in km
    const dLat = (lat2 - lat1) * (Math.PI / 180);
    const dLon = (lon2 - lon1) * (Math.PI / 180);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * (Math.PI / 180)) *
        Math.cos(lat2 * (Math.PI / 180)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private computeScore(rating: number, rawDistance: number | null, maxDistance: number, hasLocation: boolean): number {
    const rScore = (rating || 0) / 5;
    if (hasLocation && rawDistance !== null) {
      const normDist = Math.min(1, rawDistance / maxDistance);
      return rScore * 0.6 + (1 - normDist) * 0.4;
    }
    return rScore;
  }

  async searchCars(query: CarsQueryDto, isAdmin: boolean): Promise<PaginatedResult<any>> {
    const where: any = {};

    if (query.city) {
      where.vendor = {
        city: { equals: query.city, mode: 'insensitive' },
      };
    }

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
      if (!where.vendor) where.vendor = {};
      where.vendor.rating = { gte: query.minRating };
    }

    if (query.tripType) {
      where.availableTripTypes = { has: query.tripType };
    }

    const allCars = await this.prisma.car.findMany({
      where,
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
            isSponsored: true,
            boostExpiresAt: true,
          },
        },
      },
    });

    const hasLocation = query.lat !== undefined && query.lng !== undefined;
    const now = new Date();

    let processedCars = allCars.map((car) => {
      let rawDistance: number | null = null;
      let distanceKm: number | null = null;

      if (
        hasLocation &&
        car.vendor.latitude !== null &&
        car.vendor.latitude !== undefined &&
        car.vendor.longitude !== null &&
        car.vendor.longitude !== undefined
      ) {
        rawDistance = this.calculateHaversine(
          Number(query.lat),
          Number(query.lng),
          Number(car.vendor.latitude),
          Number(car.vendor.longitude),
        );
        distanceKm = Math.round(rawDistance * 10) / 10;
      }

      const isSponsored =
        car.vendor.isSponsored === true &&
        (!car.vendor.boostExpiresAt || new Date(car.vendor.boostExpiresAt) > now);

      const vendorCopy = {
        ...car.vendor,
        isSponsored,
      };

      return {
        ...car,
        vendor: vendorCopy,
        isSponsored,
        rawDistance,
        ...(hasLocation ? { distanceKm } : {}),
      };
    });

    const distances = processedCars
      .map((c) => c.rawDistance)
      .filter((d): d is number => d !== null);
    const maxDistance = distances.length > 0 ? Math.max(...distances, 1) : 1;

    const sortBy = query.sortBy || SortByOption.RECOMMENDED;

    if (sortBy === SortByOption.NEAREST && hasLocation) {
      processedCars.sort((a, b) => {
        if (a.rawDistance === null && b.rawDistance === null) return 0;
        if (a.rawDistance === null) return 1;
        if (b.rawDistance === null) return -1;
        return a.rawDistance - b.rawDistance;
      });
    } else if (sortBy === SortByOption.PRICE_ASC) {
      processedCars.sort((a, b) => Number(a.pricePerDay) - Number(b.pricePerDay));
    } else if (sortBy === SortByOption.PRICE_DESC) {
      processedCars.sort((a, b) => Number(b.pricePerDay) - Number(a.pricePerDay));
    } else if (sortBy === SortByOption.RATING) {
      processedCars.sort((a, b) => (b.vendor.rating || 0) - (a.vendor.rating || 0));
    } else {
      // SortByOption.RECOMMENDED or RELEVANCE
      processedCars.sort((a, b) => {
        if (a.isSponsored !== b.isSponsored) {
          return a.isSponsored ? -1 : 1;
        }

        const scoreA = this.computeScore(a.vendor.rating, a.rawDistance, maxDistance, hasLocation);
        const scoreB = this.computeScore(b.vendor.rating, b.rawDistance, maxDistance, hasLocation);
        return scoreB - scoreA;
      });
    }

    const total = processedCars.length;
    const page = query.page || 1;
    const limit = query.limit || 20;
    const paginated = processedCars.slice((page - 1) * limit, page * limit);

    const redactedData = paginated.map((car) => {
      const copy: any = { ...car };
      delete copy.rawDistance;
      copy.vendor = redactVendor(car.vendor, { isAdmin });
      return copy;
    });

    return {
      data: redactedData,
      total,
      page,
      totalPages: Math.ceil(total / limit),
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
