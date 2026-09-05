import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { VerificationStatus, Role, Prisma, TripType, BookingStatus, VehicleHoldStatus } from '@prisma/client';
import { CarsQueryDto, SortByOption } from './dto/cars-query.dto';
import { CreateCarDto } from './dto/create-car.dto';
import { UpdateCarDto } from './dto/update-car.dto';
import { AdminCarsQueryDto } from './dto/admin-cars-query.dto';
import { PaginatedResult } from '../common/pagination.dto';
import { SearchRankingService } from './search-ranking.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import { redactVendor } from '../common/vendor-redactor.util';

@Injectable()
export class CarsService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly searchRankingService?: SearchRankingService,
    @Optional() private readonly geoService?: GeospatialService,
    @Optional() private readonly cacheService?: RedisCacheService,
    @Optional() private readonly configService?: SystemConfigService,
  ) {}

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
    if (this.geoService) {
      return this.geoService.calculateDistanceKm(lat1, lon1, lat2, lon2);
    }
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

  async searchCars(
    query: CarsQueryDto,
    isAdmin: boolean,
  ): Promise<PaginatedResult<any>> {
    // 1. Try Redis cache for public customer searches
    const queryHash = Buffer.from(JSON.stringify(query)).toString('base64');
    const cacheKey = REDIS_NAMESPACES.CACHE.CAR_SEARCH(queryHash);

    if (!isAdmin && this.cacheService) {
      const cached = await this.cacheService.get<PaginatedResult<any>>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const where: any = {};

    // Support city-specific search or "ALL" scope
    if (query.city && query.city.trim().toUpperCase() !== 'ALL') {
      where.vendor = {
        ...(where.vendor || {}),
        city: { equals: query.city, mode: 'insensitive' },
      };
    }

    if (query.pickupHubId) {
      where.pickupHubId = query.pickupHubId;
    }

    if (query.fuelType) {
      where.fuelType = query.fuelType;
    }

    if (query.seating !== undefined) {
      where.seating = { gte: Number(query.seating) };
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

    let reqStart: Date | undefined;
    let reqEnd: Date | undefined;

    if (query.startDate || query.endDate) {
      if (!query.startDate || !query.endDate) {
        throw new BadRequestException(
          'Both startDate and endDate must be provided for date-based availability search.',
        );
      }

      reqStart = new Date(query.startDate);
      reqEnd = new Date(query.endDate);

      if (isNaN(reqStart.getTime()) || isNaN(reqEnd.getTime())) {
        throw new BadRequestException(
          'Invalid date format for startDate or endDate.',
        );
      }

      if (reqStart >= reqEnd) {
        throw new BadRequestException('startDate must be before endDate.');
      }
    }

    if (reqStart && reqEnd) {
      const overlappingBookings = await this.prisma.booking.findMany({
        where: {
          status: {
            in: [
              BookingStatus.PENDING,
              BookingStatus.CONFIRMED,
              BookingStatus.HANDOVER_READY,
              BookingStatus.ONGOING,
              BookingStatus.RETURN_PENDING,
            ],
          },
          startDate: { lt: reqEnd },
          endDate: { gt: reqStart },
        },
        select: { carId: true },
        distinct: ['carId'],
      });

      const overlappingBlocks = await this.prisma.vehicleBlock.findMany({
        where: {
          startDate: { lt: reqEnd },
          endDate: { gt: reqStart },
        },
        select: { carId: true },
        distinct: ['carId'],
      });

      const overlappingHolds = await this.prisma.vehicleHold.findMany({
        where: {
          status: VehicleHoldStatus.ACTIVE,
          expiresAt: { gt: new Date() },
          startDate: { lt: reqEnd },
          endDate: { gt: reqStart },
        },
        select: { carId: true },
        distinct: ['carId'],
      });

      const excludedCarIds = Array.from(
        new Set([
          ...overlappingBookings.map((b) => b.carId),
          ...overlappingBlocks.map((b) => b.carId),
          ...overlappingHolds.map((h) => h.carId),
        ]),
      );

      if (excludedCarIds.length > 0) {
        where.id = { notIn: excludedCarIds };
      }
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
        pickupHub: {
          select: {
            id: true,
            name: true,
            address: true,
            locality: true,
            city: true,
            latitude: true,
            longitude: true,
            serviceRadiusKm: true,
            operatingHours: true,
          },
        },
        mileagePackages: {
          where: { isActive: true },
          orderBy: [{ isDefault: 'desc' }, { basePricePerDay: 'asc' }],
        },
        sponsoredCampaigns: {
          where: {
            status: 'ACTIVE',
          },
          select: {
            id: true,
            status: true,
            startDate: true,
            endDate: true,
            boostMultiplier: true,
          },
        },
        featuredListings: {
          where: {
            isActive: true,
          },
          select: {
            id: true,
            isActive: true,
            startDate: true,
            endDate: true,
            priority: true,
          },
        },
      },
    });

    let availableCars = allCars;
    if (reqStart && reqEnd) {
      availableCars = allCars.filter((car) => {
        if (!car.blockedDates || car.blockedDates.length === 0) {
          return true;
        }
        const isBlocked = car.blockedDates.some((bd: Date) => {
          const bTime = new Date(bd).getTime();
          return bTime >= reqStart!.getTime() && bTime <= reqEnd!.getTime();
        });
        return !isBlocked;
      });
    }

    const hasLocation = query.lat !== undefined && query.lng !== undefined;
    const userLat = hasLocation ? Number(query.lat) : undefined;
    const userLng = hasLocation ? Number(query.lng) : undefined;
    const maxRadius = query.radiusKm ? Number(query.radiusKm) : 100;
    const now = new Date();

    // 2. Fetch dynamic ranking weights from SystemConfigService
    const rankingConfig = this.configService
      ? await this.configService.getSearchRankingConfig()
      : undefined;

    // 3. Resolve vehicle effective coordinates (Pickup Hub takes priority over primary vendor address)
    const rankableVehicles = availableCars.map((car) => {
      const effLat = car.pickupHub?.latitude ?? car.vendor.latitude;
      const effLng = car.pickupHub?.longitude ?? car.vendor.longitude;

      return {
        ...car,
        pricePerDay: Number(car.pricePerDay),
        vendor: {
          ...car.vendor,
          latitude: effLat,
          longitude: effLng,
          rating: car.vendor.rating || 0,
        },
      };
    });

    let scoredVehicles = this.searchRankingService
      ? this.searchRankingService.rankVehicles(
          rankableVehicles,
          userLat,
          userLng,
          rankingConfig,
        )
      : rankableVehicles.map((car) => {
          let distanceKm: number | null = null;
          if (
            hasLocation &&
            car.vendor.latitude != null &&
            car.vendor.longitude != null
          ) {
            distanceKm = this.calculateHaversine(
              userLat!,
              userLng!,
              car.vendor.latitude,
              car.vendor.longitude,
            );
          }
          return {
            car,
            distanceKm,
            scoreBreakdown: { finalCompositeScore: 1 },
          };
        });

    // Apply distance radius cutoff if geo-searching
    if (hasLocation && query.radiusKm) {
      scoredVehicles = scoredVehicles.filter(
        (s) => s.distanceKm === null || s.distanceKm <= maxRadius,
      );
    }

    const sortBy = query.sortBy || SortByOption.RECOMMENDED;

    let sorted = [...scoredVehicles];
    if (sortBy === SortByOption.NEAREST && hasLocation) {
      sorted.sort((a, b) => {
        if (a.distanceKm === null && b.distanceKm === null) return 0;
        if (a.distanceKm === null) return 1;
        if (b.distanceKm === null) return -1;
        return a.distanceKm - b.distanceKm;
      });
    } else if (sortBy === SortByOption.PRICE_ASC) {
      sorted.sort(
        (a, b) => Number(a.car.pricePerDay) - Number(b.car.pricePerDay),
      );
    } else if (sortBy === SortByOption.PRICE_DESC) {
      sorted.sort(
        (a, b) => Number(b.car.pricePerDay) - Number(a.car.pricePerDay),
      );
    } else if (sortBy === SortByOption.RATING) {
      sorted.sort(
        (a, b) => (b.car.vendor.rating || 0) - (a.car.vendor.rating || 0),
      );
    } else {
      // SortByOption.RECOMMENDED: Primary sort by finalCompositeScore
      sorted.sort(
        (a, b) =>
          b.scoreBreakdown.finalCompositeScore -
          a.scoreBreakdown.finalCompositeScore,
      );
    }

    const processedCars = sorted.map((s) => {
      const isSponsored =
        s.car.vendor.isSponsored === true &&
        (!s.car.vendor.boostExpiresAt ||
          new Date(s.car.vendor.boostExpiresAt) > now);

      return {
        ...s.car,
        vendor: {
          ...s.car.vendor,
          isSponsored,
        },
        isSponsored,
        pickupHub: s.car.pickupHub || null,
        ...(s.distanceKm !== null ? { distanceKm: s.distanceKm } : {}),
      };
    });

    const total = processedCars.length;
    const page = query.page || 1;
    const limit = Math.min(query.limit || 20, 50); // Bound pagination max 50
    const paginated = processedCars.slice((page - 1) * limit, page * limit);

    const redactedData = paginated.map((car) => {
      const copy: any = { ...car };
      delete copy.rawDistance;
      copy.vendor = redactVendor(car.vendor, { isAdmin });
      return copy;
    });

    const result: PaginatedResult<any> = {
      data: redactedData,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };

    // Cache public search results in Redis with 60-second TTL
    if (!isAdmin && this.cacheService) {
      await this.cacheService.set(cacheKey, result, DEFAULT_CACHE_TTLS.SHORT_TERM);
    }

    return result;
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
        pickupHub: {
          select: {
            id: true,
            name: true,
            address: true,
            locality: true,
            city: true,
            latitude: true,
            longitude: true,
            serviceRadiusKm: true,
            operatingHours: true,
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
        pickupHub: true,
        vendor: true,
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

  private async invalidateCarCaches(carId?: string) {
    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:search:cars:*');
      if (carId) {
        await this.cacheService.delete(REDIS_NAMESPACES.CACHE.CAR_DETAIL(carId));
      }
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

    if (dto.pickupHubId && this.prisma.pickupHub) {
      const hub = await this.prisma.pickupHub.findUnique({
        where: { id: dto.pickupHubId },
      });
      if (!hub || hub.vendorId !== vendor.id || !hub.isActive) {
        throw new BadRequestException('Invalid or inactive pickup hub specified.');
      }
    }

    const created = await this.prisma.car.create({
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
        pickupHubId: dto.pickupHubId ?? undefined,
      },
    });

    await this.invalidateCarCaches(created.id);
    return created;
  }

  async updateCar(carId: string, userId: string, dto: UpdateCarDto) {
    await this.verifyOwnership(carId, userId);

    await this.validateAvailableTripTypes(dto.availableTripTypes);

    if (dto.pickupHubId && this.prisma.pickupHub) {
      const car = await this.prisma.car.findUnique({
        where: { id: carId },
        select: { vendorId: true },
      });
      const hub = await this.prisma.pickupHub.findUnique({
        where: { id: dto.pickupHubId },
      });
      if (!hub || hub.vendorId !== car?.vendorId || !hub.isActive) {
        throw new BadRequestException('Invalid or inactive pickup hub specified.');
      }
    }

    const updated = await this.prisma.car.update({
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
        pickupHubId: dto.pickupHubId ?? undefined,
      },
    });

    await this.invalidateCarCaches(carId);
    return updated;
  }

  async updateAvailability(
    carId: string,
    userId: string,
    isAvailable: boolean,
  ) {
    await this.verifyOwnership(carId, userId);

    const updated = await this.prisma.car.update({
      where: { id: carId },
      data: { isAvailable },
    });

    await this.invalidateCarCaches(carId);
    return updated;
  }

  async updateBlockedDates(
    carId: string,
    userId: string,
    blockedDates: string[],
  ) {
    await this.verifyOwnership(carId, userId);

    const dates = blockedDates.map((d) => new Date(d));

    const updated = await this.prisma.car.update({
      where: { id: carId },
      data: { blockedDates: dates },
    });

    await this.invalidateCarCaches(carId);
    return updated;
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
