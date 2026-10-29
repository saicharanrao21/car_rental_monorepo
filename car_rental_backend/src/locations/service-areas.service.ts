import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import { AuditLogService } from '../admin/audit-log.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { DEFAULT_SYSTEM_CONFIGS, LocationRulesConfig } from '../config-engine/system-config.interface';
import {
  ServiceAreaStatus,
  VerificationStatus,
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  BookingStatus,
} from '@prisma/client';
import {
  CreateCityDto,
  UpdateCityDto,
  CreateServiceAreaDto,
  UpdateServiceAreaDto,
  AssignVendorServiceAreaDto,
  ServiceAreaQueryDto,
  ServiceabilityQueryDto,
  ResolvedServiceAreaResult,
  NearestServiceAreaInfo,
} from './dto/service-area.dto';

@Injectable()
export class ServiceAreasService {
  private readonly logger = new Logger(ServiceAreasService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly geoService: GeospatialService,
    @Optional() private readonly cacheService?: RedisCacheService,
    @Optional() private readonly auditLogService?: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {}

  // =========================================================================
  // 1. CITY MANAGEMENT (Admin-Controlled authoritative cities)
  // =========================================================================

  async findAllCities(includeInactive = false) {
    const cacheKey = REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES();
    if (!includeInactive && this.cacheService) {
      const cached = await this.cacheService.get<any[]>(cacheKey);
      if (cached) return cached;
    }

    const where = includeInactive ? {} : { status: { not: ServiceAreaStatus.INACTIVE } };
    const cities = await this.prisma.supportedCity.findMany({
      where,
      include: {
        _count: {
          select: { serviceAreas: true },
        },
      },
      orderBy: { name: 'asc' },
    });

    if (!includeInactive && this.cacheService) {
      await this.cacheService.set(cacheKey, cities, DEFAULT_CACHE_TTLS.LONG_TERM);
    }
    return cities;
  }

  async findCityById(id: string) {
    const city = await this.prisma.supportedCity.findUnique({
      where: { id },
      include: {
        serviceAreas: {
          orderBy: { name: 'asc' },
        },
      },
    });
    if (!city) {
      throw new NotFoundException(`City with ID [${id}] not found.`);
    }
    return city;
  }

  async createCity(dto: CreateCityDto, adminUserId: string) {
    const name = dto.name.trim();
    const normalizedName = name.toUpperCase();

    // Check duplicate by name or normalizedName
    const existing = await this.prisma.supportedCity.findFirst({
      where: {
        OR: [
          { name: { equals: name, mode: 'insensitive' } },
          { normalizedName: { equals: normalizedName } },
        ],
      },
    });
    if (existing) {
      throw new ConflictException(`City with name "${name}" already exists.`);
    }

    const status = dto.status || ServiceAreaStatus.ACTIVE;
    const city = await this.prisma.supportedCity.create({
      data: {
        name,
        normalizedName,
        state: dto.state.trim(),
        country: dto.country || 'India',
        latitude: dto.latitude,
        longitude: dto.longitude,
        timezone: dto.timezone || 'Asia/Kolkata',
        status,
        isActive: status === ServiceAreaStatus.ACTIVE,
        enabledTripTypes: dto.enabledTripTypes || [],
        createdBy: adminUserId,
        updatedBy: adminUserId,
      },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CITY_CREATED',
        'SupportedCity',
        city.id,
        { name: city.name, status: city.status, coordinates: [city.latitude, city.longitude] },
      );
    }

    await this.invalidateCityCaches(city.name);
    return city;
  }

  async updateCity(id: string, dto: UpdateCityDto, adminUserId: string) {
    const city = await this.prisma.supportedCity.findUnique({ where: { id } });
    if (!city) {
      throw new NotFoundException(`City with ID [${id}] not found.`);
    }

    let normalizedName: string | undefined;
    if (dto.name && dto.name.trim() !== city.name) {
      const name = dto.name.trim();
      normalizedName = name.toUpperCase();
      const duplicate = await this.prisma.supportedCity.findFirst({
        where: {
          id: { not: id },
          OR: [
            { name: { equals: name, mode: 'insensitive' } },
            { normalizedName: { equals: normalizedName } },
          ],
        },
      });
      if (duplicate) {
        throw new ConflictException(`Another city with name "${name}" already exists.`);
      }
    }

    const updatedStatus = dto.status ?? city.status;
    const isActive = updatedStatus === ServiceAreaStatus.ACTIVE;

    // Safety guard: prevent deactivation of city with active rentals
    if (this.prisma.booking && updatedStatus !== ServiceAreaStatus.ACTIVE && city.status === ServiceAreaStatus.ACTIVE) {
      const activeBookingsCount = await this.prisma.booking.count({
        where: {
          car: {
            OR: [
              { serviceArea: { cityId: id } },
              { pickupHub: { city: { equals: city.name, mode: 'insensitive' } } },
              { vendor: { city: { equals: city.name, mode: 'insensitive' } } },
            ],
          },
          status: {
            in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.PENDING],
          },
        },
      });

      if (activeBookingsCount > 0) {
        throw new BadRequestException(
          `Cannot deactivate city "${city.name}". There are ${activeBookingsCount} active or ongoing bookings in this city. Complete or resolve all active bookings before deactivating.`,
        );
      }
    }

    const updatedCity = await this.prisma.supportedCity.update({
      where: { id },
      data: {
        name: dto.name ? dto.name.trim() : undefined,
        normalizedName: normalizedName ?? (dto.name ? dto.name.trim().toUpperCase() : undefined),
        state: dto.state ? dto.state.trim() : undefined,
        country: dto.country,
        latitude: dto.latitude,
        longitude: dto.longitude,
        timezone: dto.timezone,
        status: updatedStatus,
        isActive,
        enabledTripTypes: dto.enabledTripTypes,
        updatedBy: adminUserId,
      },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CITY_UPDATED',
        'SupportedCity',
        updatedCity.id,
        { previous: city, updated: dto },
      );
    }

    await this.invalidateCityCaches(city.name);
    if (dto.name && dto.name !== city.name) {
      await this.invalidateCityCaches(dto.name);
    }
    return updatedCity;
  }

  async setCityStatus(
    id: string,
    status: ServiceAreaStatus,
    adminUserId: string,
    reason?: string,
  ) {
    const city = await this.prisma.supportedCity.findUnique({ where: { id } });
    if (!city) {
      throw new NotFoundException(`City with ID [${id}] not found.`);
    }

    // Safety guard: prevent deactivation of city with active rentals
    if (this.prisma.booking && status !== ServiceAreaStatus.ACTIVE && city.status === ServiceAreaStatus.ACTIVE) {
      const activeBookingsCount = await this.prisma.booking.count({
        where: {
          car: {
            OR: [
              { serviceArea: { cityId: id } },
              { pickupHub: { city: { equals: city.name, mode: 'insensitive' } } },
              { vendor: { city: { equals: city.name, mode: 'insensitive' } } },
            ],
          },
          status: {
            in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.PENDING],
          },
        },
      });

      if (activeBookingsCount > 0) {
        throw new BadRequestException(
          `Cannot deactivate city "${city.name}". There are ${activeBookingsCount} active or ongoing bookings in this city. Complete or resolve all active bookings before deactivating.`,
        );
      }
    }

    const updated = await this.prisma.supportedCity.update({
      where: { id },
      data: {
        status,
        isActive: status === ServiceAreaStatus.ACTIVE,
        updatedBy: adminUserId,
      },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CITY_STATUS_CHANGED',
        'SupportedCity',
        id,
        { previousStatus: city.status, newStatus: status, reason },
      );
    }

    await this.invalidateCityCaches(city.name);
    return updated;
  }

  // =========================================================================
  // 2. SERVICE AREA MANAGEMENT (Admin-defined localities & geofenced areas)
  // =========================================================================

  async findAllServiceAreas(query: ServiceAreaQueryDto) {
    const where: any = {};
    if (query.status) {
      where.status = query.status;
    }
    if (query.cityId) {
      where.cityId = query.cityId;
    } else if (query.city) {
      where.city = { name: { equals: query.city, mode: 'insensitive' } };
    }
    if (query.search) {
      where.name = { contains: query.search, mode: 'insensitive' };
    }

    return this.prisma.serviceArea.findMany({
      where,
      include: {
        city: {
          select: { id: true, name: true, state: true, status: true },
        },
        _count: {
          select: { vendorAssignments: true, cars: true },
        },
      },
      orderBy: [{ priority: 'desc' }, { name: 'asc' }],
    });
  }

  async findServiceAreaById(id: string) {
    const area = await this.prisma.serviceArea.findUnique({
      where: { id },
      include: {
        city: true,
        vendorAssignments: {
          where: { isActive: true },
          include: {
            vendor: {
              select: {
                id: true,
                businessName: true,
                ownerName: true,
                city: true,
                locality: true,
                verificationStatus: true,
                rating: true,
              },
            },
          },
        },
      },
    });
    if (!area) {
      throw new NotFoundException(`Service area with ID [${id}] not found.`);
    }
    return area;
  }

  async createServiceArea(dto: CreateServiceAreaDto, adminUserId: string) {
    const city = await this.prisma.supportedCity.findUnique({ where: { id: dto.cityId } });
    if (!city) {
      throw new NotFoundException(`City with ID [${dto.cityId}] not found.`);
    }

    const normalizedName = dto.name.trim().toUpperCase();

    // Check duplicate service area name in this city
    const existing = await this.prisma.serviceArea.findUnique({
      where: {
        cityId_normalizedName: {
          cityId: dto.cityId,
          normalizedName,
        },
      },
    });
    if (existing) {
      throw new ConflictException(
        `Service area "${dto.name}" already exists in ${city.name}.`,
      );
    }

    // Default & bounds check from platform configuration
    let radiusMeters = dto.radiusMeters ?? 5000;
    if (this.systemConfigService) {
      const config = await this.systemConfigService.getConfig<LocationRulesConfig>(
        'location.rules',
      );
      if (config && radiusMeters > config.maxServiceRadiusMeters) {
        throw new BadRequestException(
          `Radius ${radiusMeters}m exceeds configured maximum of ${config.maxServiceRadiusMeters}m.`,
        );
      }
      if (radiusMeters < config.minServiceRadiusMeters) {
        throw new BadRequestException(
          `Radius ${radiusMeters}m is below configured minimum of ${config.minServiceRadiusMeters}m.`,
        );
      }
    }

    const status = dto.status || ServiceAreaStatus.ACTIVE;
    const area = await this.prisma.serviceArea.create({
      data: {
        cityId: dto.cityId,
        name: dto.name.trim(),
        normalizedName,
        status,
        latitude: dto.latitude,
        longitude: dto.longitude,
        radiusMeters,
        priority: dto.priority ?? 0,
        createdBy: adminUserId,
        updatedBy: adminUserId,
      },
      include: { city: true },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'SERVICE_AREA_CREATED',
        'ServiceArea',
        area.id,
        { name: area.name, city: city.name, status: area.status, radiusMeters: area.radiusMeters },
      );
    }

    await this.invalidateServiceAreaCaches(city.name);
    return area;
  }

  async updateServiceArea(id: string, dto: UpdateServiceAreaDto, adminUserId: string) {
    const area = await this.prisma.serviceArea.findUnique({
      where: { id },
      include: { city: true },
    });
    if (!area) {
      throw new NotFoundException(`Service area with ID [${id}] not found.`);
    }

    const cityId = dto.cityId ?? area.cityId;
    let normalizedName: string | undefined;

    if (dto.name || dto.cityId) {
      const name = (dto.name ?? area.name).trim();
      normalizedName = name.toUpperCase();

      const existing = await this.prisma.serviceArea.findFirst({
        where: {
          id: { not: id },
          cityId,
          normalizedName,
        },
      });
      if (existing) {
        throw new ConflictException(
          `Another service area named "${name}" already exists in this city.`,
        );
      }
    }

    const updated = await this.prisma.serviceArea.update({
      where: { id },
      data: {
        cityId: dto.cityId,
        name: dto.name ? dto.name.trim() : undefined,
        normalizedName,
        status: dto.status,
        latitude: dto.latitude,
        longitude: dto.longitude,
        radiusMeters: dto.radiusMeters,
        priority: dto.priority,
        updatedBy: adminUserId,
      },
      include: { city: true },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'SERVICE_AREA_UPDATED',
        'ServiceArea',
        id,
        { previous: area, updated: dto },
      );
    }

    await this.invalidateServiceAreaCaches(area.city.name);
    return updated;
  }

  async setServiceAreaStatus(
    id: string,
    status: ServiceAreaStatus,
    adminUserId: string,
    reason?: string,
  ) {
    const area = await this.prisma.serviceArea.findUnique({
      where: { id },
      include: { city: true },
    });
    if (!area) {
      throw new NotFoundException(`Service area with ID [${id}] not found.`);
    }

    // Guard: Cannot activate service area if parent city is INACTIVE
    if (status === ServiceAreaStatus.ACTIVE && area.city.status === ServiceAreaStatus.INACTIVE) {
      throw new BadRequestException(
        `Cannot activate service area "${area.name}" because its parent city "${area.city.name}" is INACTIVE. Activate the city first.`,
      );
    }

    // Guard: Cannot deactivate service area with active rentals
    if (this.prisma.booking && status !== ServiceAreaStatus.ACTIVE && area.status === ServiceAreaStatus.ACTIVE) {
      const activeBookingsCount = await this.prisma.booking.count({
        where: {
          car: { serviceAreaId: id },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.PENDING] },
        },
      });

      if (activeBookingsCount > 0) {
        throw new BadRequestException(
          `Cannot deactivate service area "${area.name}". There are ${activeBookingsCount} active bookings in this area. Complete or resolve all active bookings before deactivating.`,
        );
      }
    }

    const updated = await this.prisma.serviceArea.update({
      where: { id },
      data: {
        status,
        updatedBy: adminUserId,
      },
      include: { city: true },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'SERVICE_AREA_STATUS_CHANGED',
        'ServiceArea',
        id,
        { previousStatus: area.status, newStatus: status, reason },
      );
    }

    await this.invalidateServiceAreaCaches(area.city.name);
    return updated;
  }

  // =========================================================================
  // 3. VENDOR COVERAGE (Vendor ↔ Service Area assignments)
  // =========================================================================

  async getVendorServiceAreas(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) {
      throw new NotFoundException(`Vendor [${vendorId}] not found.`);
    }

    return this.prisma.vendorServiceArea.findMany({
      where: { vendorId },
      include: {
        serviceArea: {
          include: { city: true },
        },
      },
      orderBy: [{ isPrimary: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async assignVendorToServiceArea(
    dto: AssignVendorServiceAreaDto,
    adminUserId: string,
  ) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: dto.vendorId } });
    if (!vendor) {
      throw new NotFoundException(`Vendor with ID [${dto.vendorId}] not found.`);
    }

    const area = await this.prisma.serviceArea.findUnique({
      where: { id: dto.serviceAreaId },
      include: { city: true },
    });
    if (!area) {
      throw new NotFoundException(`Service area with ID [${dto.serviceAreaId}] not found.`);
    }

    // Check existing assignment
    const existing = await this.prisma.vendorServiceArea.findUnique({
      where: {
        vendorId_serviceAreaId: {
          vendorId: dto.vendorId,
          serviceAreaId: dto.serviceAreaId,
        },
      },
    });

    if (existing && existing.isActive) {
      throw new ConflictException(
        `Vendor "${vendor.businessName}" is already assigned to service area "${area.name}".`,
      );
    }

    // If isPrimary is requested, demote previous primary
    if (dto.isPrimary) {
      await this.prisma.vendorServiceArea.updateMany({
        where: { vendorId: dto.vendorId, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    let assignment;
    if (existing && !existing.isActive) {
      // Re-activate soft-deleted/inactive assignment
      assignment = await this.prisma.vendorServiceArea.update({
        where: { id: existing.id },
        data: {
          isActive: true,
          isPrimary: dto.isPrimary ?? existing.isPrimary,
          assignedBy: adminUserId,
        },
        include: { serviceArea: { include: { city: true } } },
      });
    } else {
      assignment = await this.prisma.vendorServiceArea.create({
        data: {
          vendorId: dto.vendorId,
          serviceAreaId: dto.serviceAreaId,
          isPrimary: dto.isPrimary ?? false,
          isActive: true,
          assignedBy: adminUserId,
        },
        include: { serviceArea: { include: { city: true } } },
      });
    }

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'VENDOR_SERVICE_AREA_ASSIGNED',
        'VendorServiceArea',
        assignment.id,
        {
          vendorId: vendor.id,
          vendorName: vendor.businessName,
          serviceAreaId: area.id,
          serviceAreaName: area.name,
          city: area.city.name,
          isPrimary: assignment.isPrimary,
        },
      );
    }

    await this.invalidateVendorCoverageCaches(dto.vendorId);
    return assignment;
  }

  async removeVendorFromServiceArea(
    vendorId: string,
    serviceAreaId: string,
    adminUserId: string,
    reason?: string,
  ) {
    const assignment = await this.prisma.vendorServiceArea.findUnique({
      where: {
        vendorId_serviceAreaId: {
          vendorId,
          serviceAreaId,
        },
      },
      include: {
        vendor: { select: { businessName: true } },
        serviceArea: { select: { name: true } },
      },
    });

    if (!assignment) {
      throw new NotFoundException('Vendor service area assignment not found.');
    }

    await this.prisma.vendorServiceArea.delete({
      where: { id: assignment.id },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'VENDOR_SERVICE_AREA_REMOVED',
        'VendorServiceArea',
        assignment.id,
        {
          vendorId,
          serviceAreaId,
          vendorName: assignment.vendor?.businessName,
          serviceAreaName: assignment.serviceArea?.name,
          reason,
        },
      );
    }

    await this.invalidateVendorCoverageCaches(vendorId);
    return { success: true, message: 'Vendor service area assignment removed successfully.' };
  }

  async setVendorPrimaryArea(
    vendorId: string,
    serviceAreaId: string,
    adminUserId: string,
  ) {
    const assignment = await this.prisma.vendorServiceArea.findUnique({
      where: {
        vendorId_serviceAreaId: {
          vendorId,
          serviceAreaId,
        },
      },
    });

    if (!assignment) {
      throw new NotFoundException('Vendor service area assignment not found.');
    }

    // Demote any existing primary for this vendor
    await this.prisma.vendorServiceArea.updateMany({
      where: { vendorId, isPrimary: true },
      data: { isPrimary: false },
    });

    // Set new primary
    const updated = await this.prisma.vendorServiceArea.update({
      where: { id: assignment.id },
      data: { isPrimary: true },
      include: { serviceArea: { include: { city: true } } },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'VENDOR_SERVICE_AREA_PRIMARY_SET',
        'VendorServiceArea',
        assignment.id,
        { vendorId, serviceAreaId },
      );
    }

    await this.invalidateVendorCoverageCaches(vendorId);
    return updated;
  }

  // =========================================================================
  // 4. AUTHORITATIVE LOCATION RESOLUTION & SERVICEABILITY EVALUATION
  // =========================================================================

  /**
   * Server-authoritative resolution:
   * Evaluates coordinate against Admin-defined Service Areas, determines SERVICEABLE,
   * COMING_SOON, or NO_MATCH, and computes geographic distances to nearest active areas.
   */
  async resolveServiceability(
    query: ServiceabilityQueryDto,
  ): Promise<ResolvedServiceAreaResult> {
    const { latitude: lat, longitude: lng, city: cityHint } = query;
    this.validateCoordinates(lat, lng);

    const cacheKey = REDIS_NAMESPACES.CACHE.SERVICEABILITY(lat, lng) +
      (cityHint ? `:${cityHint.toLowerCase()}` : '');

    if (this.cacheService) {
      const cached = await this.cacheService.get<ResolvedServiceAreaResult>(cacheKey);
      if (cached) return cached;
    }

    // Load active and coming soon service areas in non-inactive cities
    const candidateAreas = await this.prisma.serviceArea.findMany({
      where: {
        status: { in: [ServiceAreaStatus.ACTIVE, ServiceAreaStatus.COMING_SOON] },
        city: { status: { not: ServiceAreaStatus.INACTIVE } },
        ...(cityHint ? { city: { name: { equals: cityHint, mode: 'insensitive' } } } : {}),
      },
      include: {
        city: true,
      },
    });

    // Score candidates by distance and determine if inside boundary radius
    const scoredCandidates = candidateAreas.map((area) => {
      const distanceKm = this.geoService.calculateDistanceKm(
        lat,
        lng,
        area.latitude,
        area.longitude,
      );
      const isInside = (distanceKm * 1000) <= area.radiusMeters;
      return { area, distanceKm, isInside };
    });

    // Candidate areas that contain the coordinate
    const insideMatches = scoredCandidates.filter((c) => c.isInside);

    // Active areas for computing nearest fallback
    const allActiveCandidates = scoredCandidates
      .filter((c) => c.area.status === ServiceAreaStatus.ACTIVE)
      .sort((a, b) => a.distanceKm - b.distanceKm);

    let result: ResolvedServiceAreaResult;

    if (insideMatches.length > 0) {
      // Sort inside matches: ACTIVE before COMING_SOON, then highest priority, then closest center
      insideMatches.sort((a, b) => {
        if (a.area.status !== b.area.status) {
          return a.area.status === ServiceAreaStatus.ACTIVE ? -1 : 1;
        }
        if (a.area.priority !== b.area.priority) {
          return b.area.priority - a.area.priority;
        }
        return a.distanceKm - b.distanceKm;
      });

      const best = insideMatches[0];

      if (best.area.status === ServiceAreaStatus.ACTIVE) {
        // ACTIVE SERVICE AREA
        const vendorCount = await this.prisma.vendorServiceArea.count({
          where: {
            serviceAreaId: best.area.id,
            isActive: true,
            vendor: { verificationStatus: VerificationStatus.VERIFIED },
          },
        });

        const alternateActive = allActiveCandidates
          .filter((c) => c.area.id !== best.area.id)
          .slice(0, 3)
          .map((c) => this.mapToNearestInfo(c.area, c.distanceKm));

        result = {
          state: 'SERVICEABLE',
          resolvedCity: {
            id: best.area.city.id,
            name: best.area.city.name,
            state: best.area.city.state,
            country: best.area.city.country,
            latitude: best.area.city.latitude,
            longitude: best.area.city.longitude,
            timezone: best.area.city.timezone,
          },
          resolvedServiceArea: {
            id: best.area.id,
            name: best.area.name,
            status: best.area.status,
            latitude: best.area.latitude,
            longitude: best.area.longitude,
            radiusMeters: best.area.radiusMeters,
            priority: best.area.priority,
          },
          availableVendorsCount: vendorCount,
          nearestActiveAreas: alternateActive,
        };
      } else {
        // COMING SOON SERVICE AREA
        const nearestActive = allActiveCandidates
          .slice(0, 3)
          .map((c) => this.mapToNearestInfo(c.area, c.distanceKm));

        const closest = nearestActive[0];
        const message = closest
          ? `DriveGo is coming soon to ${best.area.name}. Currently available near you: ${closest.name} (${closest.distanceKm.toFixed(1)} km).`
          : `DriveGo is coming soon to ${best.area.name}.`;

        result = {
          state: 'COMING_SOON',
          resolvedCity: {
            id: best.area.city.id,
            name: best.area.city.name,
            state: best.area.city.state,
            country: best.area.city.country,
            latitude: best.area.city.latitude,
            longitude: best.area.city.longitude,
            timezone: best.area.city.timezone,
          },
          resolvedServiceArea: {
            id: best.area.id,
            name: best.area.name,
            status: best.area.status,
            latitude: best.area.latitude,
            longitude: best.area.longitude,
            radiusMeters: best.area.radiusMeters,
            priority: best.area.priority,
          },
          message,
          nearestActiveAreas: nearestActive,
        };
      }
    } else {
      // NO MATCH — Coordinate outside any defined service area
      // If cityHint was provided and produced no candidate, expand to all active areas platform-wide
      let activeAreasToScore = allActiveCandidates;
      if (activeAreasToScore.length === 0 && cityHint) {
        const platformActiveAreas = await this.prisma.serviceArea.findMany({
          where: {
            status: ServiceAreaStatus.ACTIVE,
            city: { status: { not: ServiceAreaStatus.INACTIVE } },
          },
          include: { city: true },
        });
        activeAreasToScore = platformActiveAreas
          .map((a) => ({
            area: a,
            distanceKm: this.geoService.calculateDistanceKm(lat, lng, a.latitude, a.longitude),
            isInside: false,
          }))
          .sort((a, b) => a.distanceKm - b.distanceKm);
      }

      const nearestActive = activeAreasToScore
        .slice(0, 3)
        .map((c) => this.mapToNearestInfo(c.area, c.distanceKm));

      const closest = nearestActive[0];
      const message = closest
        ? `DriveGo is not currently available at your exact location. Nearest available service area: ${closest.name}, ${closest.cityName} (${closest.distanceKm.toFixed(1)} km).`
        : `DriveGo does not currently have active service areas in this region.`;

      result = {
        state: 'NO_MATCH',
        message,
        nearestActiveAreas: nearestActive,
      };
    }

    if (this.cacheService) {
      await this.cacheService.set(cacheKey, result, DEFAULT_CACHE_TTLS.MEDIUM_TERM);
    }
    return result;
  }

  // =========================================================================
  // HELPER METHODS & CACHE INVALIDATION
  // =========================================================================

  private mapToNearestInfo(area: any, distanceKm: number): NearestServiceAreaInfo {
    return {
      id: area.id,
      name: area.name,
      cityName: area.city?.name ?? '',
      cityId: area.cityId,
      distanceKm: Number(distanceKm.toFixed(2)),
      latitude: area.latitude,
      longitude: area.longitude,
      status: area.status,
    };
  }

  private validateCoordinates(lat: number, lng: number) {
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new BadRequestException(
        `Invalid GPS coordinates [lat: ${lat}, lng: ${lng}]. Latitude must be between -90 and 90, Longitude between -180 and 180.`,
      );
    }
  }

  private async invalidateCityCaches(cityName?: string) {
    if (!this.cacheService) return;
    try {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES());
      if (cityName) {
        await this.cacheService.delete(REDIS_NAMESPACES.CACHE.CITY_DETAIL(cityName));
        await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SERVICE_AREAS(cityName));
      }
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SERVICE_AREAS());
    } catch (err) {
      this.logger.warn(`Failed to invalidate city caches: ${err}`);
    }
  }

  private async invalidateServiceAreaCaches(cityName?: string) {
    if (!this.cacheService) return;
    try {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SERVICE_AREAS());
      if (cityName) {
        await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SERVICE_AREAS(cityName));
      }
      // Also invalidate search caches because inventory eligibility depends on area availability
      await this.cacheService.invalidatePattern('cache:search:cars:*');
      await this.cacheService.invalidatePattern('cache:serviceability:*');
    } catch (err) {
      this.logger.warn(`Failed to invalidate service area caches: ${err}`);
    }
  }

  private async invalidateVendorCoverageCaches(vendorId: string) {
    if (!this.cacheService) return;
    try {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_SERVICE_AREAS(vendorId));
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_DETAIL(vendorId));
      await this.cacheService.invalidatePattern('cache:search:cars:*');
      await this.cacheService.invalidatePattern('cache:serviceability:*');
    } catch (err) {
      this.logger.warn(`Failed to invalidate vendor coverage caches: ${err}`);
    }
  }

  // =========================================================================
  // OPERATIONAL READINESS & IMPACT PREVIEWS (PHASE 2 CONTROL TOWER)
  // =========================================================================

  async getServiceAreaReadiness(id: string) {
    const area = await this.prisma.serviceArea.findUnique({
      where: { id },
      include: {
        city: true,
        vendorAssignments: {
          where: { isActive: true },
          include: {
            vendor: {
              select: { id: true, businessName: true, verificationStatus: true },
            },
          },
        },
        cars: {
          where: {
            operationalStatus: VehicleOperationalStatus.ACTIVE,
            verificationStatus: VehicleVerificationStatus.VERIFIED,
            isAvailable: true,
          },
          select: { id: true, make: true, model: true, registrationNumber: true },
        },
      },
    });

    if (!area) {
      throw new NotFoundException(`Service area with ID [${id}] not found.`);
    }

    const cityActive = area.city.status === ServiceAreaStatus.ACTIVE && area.city.isActive;
    const validGeometry = area.latitude !== 0 && area.longitude !== 0 && area.radiusMeters > 0;
    const activeVendorsCount = area.vendorAssignments.filter(
      (va) =>
        va.vendor &&
        va.vendor.verificationStatus === VerificationStatus.VERIFIED,
    ).length;
    const bookableCarsCount = area.cars.length;

    const checklist = [
      {
        criterion: 'PARENT_CITY_ACTIVE',
        label: 'Parent City Status',
        passed: cityActive,
        description: cityActive
          ? `Parent city "${area.city.name}" is LIVE & ACTIVE.`
          : `Parent city "${area.city.name}" is currently INACTIVE.`,
      },
      {
        criterion: 'VALID_GEOMETRY',
        label: 'Coverage Geometry & Radius',
        passed: validGeometry,
        description: validGeometry
          ? `Valid center (${area.latitude.toFixed(4)}, ${area.longitude.toFixed(4)}) with ${(area.radiusMeters / 1000).toFixed(1)} km service radius.`
          : 'Invalid coordinates or radius.',
      },
      {
        criterion: 'APPROVED_VENDOR_COVERAGE',
        label: 'Approved Partner Yard Coverage',
        passed: activeVendorsCount >= 1,
        description: activeVendorsCount >= 1
          ? `${activeVendorsCount} approved vendor(s) operating in this area.`
          : 'No approved vendors assigned to this service area.',
      },
      {
        criterion: 'AVAILABLE_FLEET_INVENTORY',
        label: 'Bookable Fleet Inventory',
        passed: bookableCarsCount >= 1,
        description: bookableCarsCount >= 1
          ? `${bookableCarsCount} verified operational vehicle(s) ready for customer booking.`
          : 'No operational vehicles currently assigned to this area.',
      },
    ];

    const isReadyToLaunch = checklist.every((c) => c.passed);
    const blockingReasons = checklist.filter((c) => !c.passed).map((c) => c.description);

    return {
      serviceAreaId: id,
      name: area.name,
      cityName: area.city.name,
      currentStatus: area.status,
      isReadyToLaunch,
      checklist,
      blockingReasons,
      counts: {
        activeVendorsCount,
        bookableCarsCount,
        radiusMeters: area.radiusMeters,
      },
    };
  }

  async getServiceAreaImpact(id: string) {
    const area = await this.prisma.serviceArea.findUnique({
      where: { id },
      include: {
        city: true,
        vendorAssignments: {
          where: { isActive: true },
          include: {
            vendor: {
              select: { id: true, businessName: true, ownerName: true },
            },
          },
        },
        cars: {
          where: { isAvailable: true },
          select: { id: true, make: true, model: true, registrationNumber: true, operationalStatus: true },
        },
      },
    });

    if (!area) {
      throw new NotFoundException(`Service area with ID [${id}] not found.`);
    }

    const carIds = area.cars.map((c) => c.id);
    const upcomingBookings = await this.prisma.booking.findMany({
      where: {
        carId: { in: carIds },
        status: { in: ['CONFIRMED', 'PENDING'] },
        startDate: { gte: new Date() },
      },
      select: {
        id: true,
        startDate: true,
        endDate: true,
        status: true,
        totalFare: true,
        customer: { select: { id: true, name: true, phone: true } },
      },
      take: 20,
      orderBy: { startDate: 'asc' },
    });

    const activeRentals = await this.prisma.booking.count({
      where: {
        carId: { in: carIds },
        status: { in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.HANDOVER_READY, BookingStatus.RETURN_PENDING] },
      },
    });

    const affectedVendors = area.vendorAssignments.map((va) => ({
      vendorId: va.vendor.id,
      name: va.vendor.businessName || va.vendor.ownerName,
      isPrimary: va.isPrimary,
    }));

    const recommendations: string[] = [];
    if (activeRentals > 0) {
      recommendations.push(
        `There are ${activeRentals} active rental(s) in progress. Pausing this area will not interrupt active trips, but return logistics must be preserved.`,
      );
    }
    if (upcomingBookings.length > 0) {
      recommendations.push(
        `${upcomingBookings.length} confirmed upcoming reservation(s) exist. Existing bookings will retain historical fulfillment terms; new bookings will be blocked.`,
      );
    }
    if (affectedVendors.length > 0) {
      recommendations.push(
        `${affectedVendors.length} operating vendor(s) will be excluded from customer search in this area.`,
      );
    }

    return {
      serviceAreaId: id,
      name: area.name,
      cityName: area.city.name,
      currentStatus: area.status,
      affectedVendorsCount: affectedVendors.length,
      affectedVehiclesCount: area.cars.length,
      upcomingBookingsCount: upcomingBookings.length,
      activeRentalsCount: activeRentals,
      affectedVendors,
      affectedVehicles: area.cars.slice(0, 15).map((c) => ({
        id: c.id,
        name: `${c.make} ${c.model}`,
        regNumber: c.registrationNumber,
        status: c.operationalStatus,
      })),
      upcomingBookings: upcomingBookings.map((b) => ({
        id: b.id,
        startDate: b.startDate,
        endDate: b.endDate,
        customerName: b.customer?.name,
        fare: b.totalFare,
      })),
      safeToDeactivate: activeRentals === 0,
      recommendations,
    };
  }

  async getCityReadiness(cityId: string) {
    const city = await this.prisma.supportedCity.findUnique({
      where: { id: cityId },
      include: {
        serviceAreas: {
          include: {
            _count: {
              select: { vendorAssignments: true, cars: true },
            },
          },
        },
      },
    });
    if (!city) {
      throw new NotFoundException(`City with ID [${cityId}] not found.`);
    }

    const totalAreas = city.serviceAreas.length;
    const activeAreas = city.serviceAreas.filter((a) => a.status === ServiceAreaStatus.ACTIVE).length;
    const areasWithVendors = city.serviceAreas.filter((a) => a._count.vendorAssignments > 0).length;
    const areasWithCars = city.serviceAreas.filter((a) => a._count.cars > 0).length;

    const checklist = [
      {
        criterion: 'HAS_SERVICE_AREAS',
        label: 'Configured Service Localities',
        passed: totalAreas > 0,
        description: totalAreas > 0 ? `${totalAreas} area(s) configured.` : 'No service areas added yet.',
      },
      {
        criterion: 'ACTIVE_SERVICE_AREAS',
        label: 'Active Service Localities',
        passed: activeAreas > 0,
        description: activeAreas > 0 ? `${activeAreas} active service area(s).` : 'No service areas in ACTIVE status.',
      },
      {
        criterion: 'PARTNER_COVERAGE',
        label: 'Vendor Partner Presence',
        passed: areasWithVendors > 0,
        description: areasWithVendors > 0 ? `${areasWithVendors} area(s) have assigned vendors.` : 'No vendors operating in this city.',
      },
      {
        criterion: 'FLEET_INVENTORY',
        label: 'Bookable Fleet Inventory',
        passed: areasWithCars > 0,
        description: areasWithCars > 0 ? `${areasWithCars} area(s) have vehicle inventory.` : 'No fleet inventory stationed in this city.',
      },
    ];

    return {
      cityId,
      cityName: city.name,
      state: city.state,
      isActive: city.isActive,
      status: city.status,
      isReadyToLaunch: checklist.every((c) => c.passed),
      checklist,
      counts: {
        totalAreas,
        activeAreas,
        areasWithVendors,
        areasWithCars,
      },
    };
  }

  async getCityImpact(cityId: string) {
    const city = await this.prisma.supportedCity.findUnique({
      where: { id: cityId },
      include: {
        serviceAreas: {
          include: {
            cars: { select: { id: true } },
            vendorAssignments: { select: { vendorId: true } },
          },
        },
      },
    });
    if (!city) {
      throw new NotFoundException(`City with ID [${cityId}] not found.`);
    }

    const allCarIds = city.serviceAreas.flatMap((a) => a.cars.map((c) => c.id));
    const allVendorIds = Array.from(new Set(city.serviceAreas.flatMap((a) => a.vendorAssignments.map((v) => v.vendorId))));

    const [upcomingBookingsCount, activeRentalsCount] = await Promise.all([
      this.prisma.booking.count({
        where: {
          carId: { in: allCarIds },
          status: { in: ['CONFIRMED', 'PENDING'] },
          startDate: { gte: new Date() },
        },
      }),
      this.prisma.booking.count({
        where: {
          carId: { in: allCarIds },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.ONGOING, BookingStatus.HANDOVER_READY, BookingStatus.RETURN_PENDING] },
        },
      }),
    ]);

    return {
      cityId,
      cityName: city.name,
      totalAreas: city.serviceAreas.length,
      affectedVendorsCount: allVendorIds.length,
      affectedVehiclesCount: allCarIds.length,
      upcomingBookingsCount,
      activeRentalsCount,
      safeToDeactivate: activeRentalsCount === 0,
      recommendations: [
        `Deactivating ${city.name} will pause all ${city.serviceAreas.length} service area(s) and block new searches across the entire city.`,
        activeRentalsCount > 0 ? `Alert: ${activeRentalsCount} active rentals are currently ongoing in ${city.name}.` : 'No active rentals currently in progress.',
      ],
    };
  }
}
