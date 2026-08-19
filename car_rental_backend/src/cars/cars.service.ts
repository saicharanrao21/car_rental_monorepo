import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { VerificationStatus, Role, Prisma, TripType } from '@prisma/client';
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
      throw new NotFoundException('Car not found.');
    }

    if (car.vendorId !== vendor.id) {
      throw new ForbiddenException(
        'You do not have permission to modify this vehicle.',
      );
    }

    return { vendor, car };
  }

  // --- Search / Ranking Algorithm ---

  private calculateHaversine(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
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

  private computeScore(
    rating: number | null,
    distanceKm: number | null,
    maxDistanceKm: number,
    hasLocation: boolean,
  ): number {
    const rScore = (rating || 0) / 5.0;
    if (hasLocation && distanceKm !== null) {
      const normDist = Math.min(distanceKm / maxDistanceKm, 1.0);
      return rScore * 0.6 + (1 - normDist) * 0.4;
    }
    return rScore;
  }

  async searchCars(
    query: CarsQueryDto,
    isAdmin: boolean,
  ): Promise<PaginatedResult<any>> {
    const where: any = {};

    if (query.city) {
      where.vendor = {
        ...(where.vendor || {}),
        city: { equals: query.city, mode: 'insensitive' },
      };
    }

    if (!isAdmin) {
      where.isAvailable = true;
      where.vendor = {
        ...(where.vendor || {}),
        verificationStatus: VerificationStatus.VERIFIED,
      };
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

    let settings = await this.prisma.platformSettings.findUnique({
      where: { id: 'singleton' },
    });
    if (!settings) {
      settings = await this.prisma.platformSettings.create({
        data: {
          id: 'singleton',
          platformName: 'DriveGo',
          gstNumber: '27AAAAA1111A1Z1',
          supportEmail: 'support@drivego.in',
          supportPhone: '+919876543210',
          appVersion: '1.0.0',
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        },
      });
    }

    let effectiveEnabledTripTypes = settings.enabledTripTypes;

    if (query.city) {
      const cityConfig = await this.prisma.supportedCity.findFirst({
        where: {
          name: { equals: query.city, mode: 'insensitive' },
          isActive: true,
        },
      });
      if (
        cityConfig &&
        cityConfig.enabledTripTypes &&
        cityConfig.enabledTripTypes.length > 0
      ) {
        effectiveEnabledTripTypes = cityConfig.enabledTripTypes;
      }
    }

    if (query.tripType) {
      if (!effectiveEnabledTripTypes.includes(query.tripType as any)) {
        return {
          data: [],
          total: 0,
          page: query.page || 1,
          totalPages: 0,
        };
      }
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
        mileagePackages: {
          where: { isActive: true },
          orderBy: [{ isDefault: 'desc' }, { basePricePerDay: 'asc' }],
        },
      },
    });

    const hasLocation = query.lat !== undefined && query.lng !== undefined;
    const now = new Date();

    const processedCars = allCars.map((car) => {
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
        (!car.vendor.boostExpiresAt ||
          new Date(car.vendor.boostExpiresAt) > now);

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
      processedCars.sort(
        (a, b) => Number(a.pricePerDay) - Number(b.pricePerDay),
      );
    } else if (sortBy === SortByOption.PRICE_DESC) {
      processedCars.sort(
        (a, b) => Number(b.pricePerDay) - Number(a.pricePerDay),
      );
    } else if (sortBy === SortByOption.RATING) {
      processedCars.sort(
        (a, b) => (b.vendor.rating || 0) - (a.vendor.rating || 0),
      );
    } else {
      // SortByOption.RECOMMENDED or RELEVANCE
      processedCars.sort((a, b) => {
        if (a.isSponsored !== b.isSponsored) {
          return a.isSponsored ? -1 : 1;
        }

        const scoreA = this.computeScore(
          a.vendor.rating,
          a.rawDistance,
          maxDistance,
          hasLocation,
        );
        const scoreB = this.computeScore(
          b.vendor.rating,
          b.rawDistance,
          maxDistance,
          hasLocation,
        );
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

  async findOne(id: string, requestingUser?: { userId: string; role: Role }) {
    const car = await this.prisma.car.findUnique({
      where: { id },
      include: {
        vendor: {
          select: {
            id: true,
            userId: true,
            businessName: true,
            ownerName: true,
            city: true,
            locality: true,
            rating: true,
            latitude: true,
            longitude: true,
            verificationStatus: true,
          },
        },
        mileagePackages: {
          where: { isActive: true },
          orderBy: [{ isDefault: 'desc' }, { basePricePerDay: 'asc' }],
        },
      },
    });

    if (!car) {
      throw new NotFoundException('Car not found');
    }

    const isAdminOrSupport =
      requestingUser?.role === Role.ADMIN ||
      requestingUser?.role === Role.SUPPORT_AGENT;
    const isOwner =
      requestingUser && car.vendor?.userId === requestingUser.userId;

    // Public / Customer policy: Car must belong to a VERIFIED vendor
    if (!isAdminOrSupport && !isOwner) {
      if (car.vendor?.verificationStatus !== VerificationStatus.VERIFIED) {
        throw new NotFoundException('Car not found');
      }
    }

    return {
      ...car,
      vendor: redactVendor(car.vendor, { isAdmin: !!isAdminOrSupport }),
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
      include: {
        mileagePackages: {
          orderBy: [{ tripType: 'asc' }, { isDefault: 'desc' }, { basePricePerDay: 'asc' }],
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getCarMileagePackages(
    carId: string,
    tripType?: TripType,
    activeOnly: boolean = true,
  ) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
    });
    if (!car) {
      throw new NotFoundException('Car not found');
    }

    return this.prisma.mileagePackage.findMany({
      where: {
        carId,
        ...(tripType ? { tripType } : {}),
        ...(activeOnly ? { isActive: true } : {}),
      },
      orderBy: [{ isDefault: 'desc' }, { basePricePerDay: 'asc' }],
    });
  }

  async createCarMileagePackage(
    userId: string,
    carId: string,
    dto: any,
  ) {
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
      throw new ForbiddenException('You do not have permission to manage this car.');
    }

    if (Number(dto.basePricePerDay) <= 0) {
      throw new BadRequestException('Base price per day must be greater than 0.');
    }
    if (dto.extraKmRate !== undefined && Number(dto.extraKmRate) < 0) {
      throw new BadRequestException('Extra km rate cannot be negative.');
    }

    const isUnlimited = dto.isUnlimited === true || dto.includedKmPerDay === null;
    let includedKm = isUnlimited ? null : Number(dto.includedKmPerDay);
    if (!isUnlimited && (!includedKm || includedKm <= 0)) {
      throw new BadRequestException('Included km per day must be at least 1, or mark as unlimited.');
    }

    if (!car.availableTripTypes.includes(dto.tripType)) {
      throw new BadRequestException(
        `Car does not support trip type ${dto.tripType}. Supported types: ${car.availableTripTypes.join(', ')}`,
      );
    }

    if (dto.isDefault) {
      await this.prisma.mileagePackage.updateMany({
        where: { carId, tripType: dto.tripType, isDefault: true },
        data: { isDefault: false },
      });
    }

    return this.prisma.mileagePackage.create({
      data: {
        carId,
        tripType: dto.tripType,
        name: dto.name ? dto.name.trim() : `${includedKm ? includedKm + ' km/day' : 'Unlimited'}`,
        includedKmPerDay: includedKm,
        basePricePerDay: new Prisma.Decimal(dto.basePricePerDay),
        extraKmRate: new Prisma.Decimal(dto.extraKmRate || 0),
        isDefault: dto.isDefault ?? false,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async updateCarMileagePackage(
    userId: string,
    carId: string,
    packageId: string,
    dto: any,
  ) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const pkg = await this.prisma.mileagePackage.findUnique({
      where: { id: packageId },
      include: { car: true },
    });
    if (!pkg || pkg.carId !== carId) {
      throw new NotFoundException('Mileage package not found for this car.');
    }

    if (pkg.car.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not have permission to manage this car.');
    }

    if (dto.basePricePerDay !== undefined && Number(dto.basePricePerDay) <= 0) {
      throw new BadRequestException('Base price per day must be greater than 0.');
    }
    if (dto.extraKmRate !== undefined && Number(dto.extraKmRate) < 0) {
      throw new BadRequestException('Extra km rate cannot be negative.');
    }

    const tripType = dto.tripType || pkg.tripType;

    if (dto.isDefault) {
      await this.prisma.mileagePackage.updateMany({
        where: { carId, tripType, isDefault: true, id: { not: packageId } },
        data: { isDefault: false },
      });
    }

    let includedKm = pkg.includedKmPerDay;
    if (dto.isUnlimited === true) {
      includedKm = null;
    } else if (dto.includedKmPerDay !== undefined) {
      if (dto.includedKmPerDay !== null && Number(dto.includedKmPerDay) <= 0) {
        throw new BadRequestException('Included km per day must be at least 1.');
      }
      includedKm = dto.includedKmPerDay !== null ? Number(dto.includedKmPerDay) : null;
    }

    return this.prisma.mileagePackage.update({
      where: { id: packageId },
      data: {
        ...(dto.tripType ? { tripType: dto.tripType } : {}),
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.basePricePerDay !== undefined
          ? { basePricePerDay: new Prisma.Decimal(dto.basePricePerDay) }
          : {}),
        ...(dto.extraKmRate !== undefined
          ? { extraKmRate: new Prisma.Decimal(dto.extraKmRate) }
          : {}),
        ...(dto.isDefault !== undefined ? { isDefault: dto.isDefault } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
        includedKmPerDay: includedKm,
      },
    });
  }

  async deleteCarMileagePackage(
    userId: string,
    carId: string,
    packageId: string,
  ) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const pkg = await this.prisma.mileagePackage.findUnique({
      where: { id: packageId },
      include: { car: true },
    });
    if (!pkg || pkg.carId !== carId) {
      throw new NotFoundException('Mileage package not found for this car.');
    }

    if (pkg.car.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not have permission to manage this car.');
    }

    const bookingCount = await this.prisma.booking.count({
      where: { mileagePackageId: packageId },
    });

    if (bookingCount > 0) {
      await this.prisma.mileagePackage.update({
        where: { id: packageId },
        data: { isActive: false, isDefault: false },
      });
      return { message: 'Package deactivated because it is referenced in existing bookings.' };
    }

    await this.prisma.mileagePackage.delete({
      where: { id: packageId },
    });
    return { message: 'Mileage package deleted successfully.' };
  }

  async adminToggleMileagePackageActive(
    carId: string,
    packageId: string,
    isActive?: boolean,
  ) {
    const pkg = await this.prisma.mileagePackage.findUnique({
      where: { id: packageId },
    });
    if (!pkg || pkg.carId !== carId) {
      throw new NotFoundException('Mileage package not found.');
    }

    const newActiveState = isActive !== undefined ? isActive : !pkg.isActive;
    return this.prisma.mileagePackage.update({
      where: { id: packageId },
      data: { isActive: newActiveState },
    });
  }

  private async validateAvailableTripTypes(tripTypes?: string[]) {
    if (!tripTypes || tripTypes.length === 0) return;

    let settings = await this.prisma.platformSettings.findUnique({
      where: { id: 'singleton' },
    });
    if (!settings) {
      settings = await this.prisma.platformSettings.create({
        data: {
          id: 'singleton',
          platformName: 'DriveGo',
          gstNumber: '27AAAAA1111A1Z1',
          supportEmail: 'support@drivego.in',
          supportPhone: '+919876543210',
          appVersion: '1.0.0',
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        },
      });
    }

    const invalidTypes = tripTypes.filter(
      (t) => !settings.enabledTripTypes.includes(t as any),
    );
    if (invalidTypes.length > 0) {
      throw new BadRequestException(
        `Trip type(s) ${invalidTypes.join(', ')} are not currently enabled on the platform.`,
      );
    }
  }

  async createCar(userId: string, dto: CreateCarDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    await this.validateAvailableTripTypes(dto.availableTripTypes);

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

    await this.validateAvailableTripTypes(dto.availableTripTypes);

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

  async updateAvailability(
    carId: string,
    userId: string,
    isAvailable: boolean,
  ) {
    await this.verifyOwnership(carId, userId);

    return this.prisma.car.update({
      where: { id: carId },
      data: { isAvailable },
    });
  }

  async updateBlockedDates(
    carId: string,
    userId: string,
    blockedDates: string[],
  ) {
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

  async getAvailabilityCalendar(carId: string, monthStr?: string) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
    });

    if (!car) {
      throw new NotFoundException('Car not found');
    }

    const now = new Date();
    let year = now.getFullYear();
    let month = now.getMonth();

    if (monthStr && /^\d{4}-\d{2}$/.test(monthStr)) {
      const [y, m] = monthStr.split('-').map(Number);
      year = y;
      month = m - 1;
    }

    const startDate = new Date(year, month, 1, 0, 0, 0, 0);
    const endDate = new Date(year, month + 1, 0, 23, 59, 59, 999);

    const activeBookings = await this.prisma.booking.findMany({
      where: {
        carId,
        status: { in: ['PENDING', 'CONFIRMED', 'HANDOVER_READY', 'ONGOING', 'RETURN_PENDING'] },
        startDate: { lte: endDate },
        endDate: { gte: startDate },
      },
      select: {
        id: true,
        startDate: true,
        endDate: true,
        status: true,
      },
    });

    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const calendar: Array<{ date: string; status: string }> = [];

    for (let day = 1; day <= daysInMonth; day++) {
      const dayDate = new Date(year, month, day, 12, 0, 0, 0);
      const dateIso = dayDate.toISOString().split('T')[0];

      const isBlocked = car.blockedDates.some(
        (bd) => bd.toISOString().split('T')[0] === dateIso,
      );

      if (isBlocked) {
        calendar.push({ date: dateIso, status: 'BLOCKED' });
        continue;
      }

      const isBooked = activeBookings.some((b) => {
        const bStart = new Date(b.startDate);
        const bEnd = new Date(b.endDate);
        return dayDate >= bStart && dayDate <= bEnd;
      });

      if (isBooked) {
        calendar.push({ date: dateIso, status: 'BOOKED' });
      } else {
        calendar.push({ date: dateIso, status: 'AVAILABLE' });
      }
    }

    return {
      carId,
      month: `${year}-${String(month + 1).padStart(2, '0')}`,
      calendar,
    };
  }
}
