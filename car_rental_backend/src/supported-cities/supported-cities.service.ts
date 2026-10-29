import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';

@Injectable()
export class SupportedCitiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  // Haversine formula calculation
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

  // 1. Public: get all active supported cities
  async findAllActive() {
    return this.prisma.supportedCity.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
    });
  }

  // 2. Public: find single nearest supported city to (lat, lng)
  async findNearest(lat: number, lng: number) {
    if (isNaN(lat) || isNaN(lng)) {
      throw new BadRequestException(
        'Invalid latitude or longitude coordinates provided.',
      );
    }

    const cities = await this.prisma.supportedCity.findMany({
      where: { isActive: true },
    });

    if (cities.length === 0) {
      throw new NotFoundException('No active supported cities found.');
    }

    let nearestCity = cities[0];
    let minDistance = this.calculateHaversine(
      lat,
      lng,
      nearestCity.latitude,
      nearestCity.longitude,
    );

    for (let i = 1; i < cities.length; i++) {
      const dist = this.calculateHaversine(
        lat,
        lng,
        cities[i].latitude,
        cities[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestCity = cities[i];
      }
    }

    return nearestCity;
  }

  // 3. Admin: find all cities (including inactive) with service areas & operational counts
  async findAllAdmin() {
    return this.prisma.supportedCity.findMany({
      include: {
        serviceAreas: {
          select: {
            id: true,
            name: true,
            status: true,
            latitude: true,
            longitude: true,
            radiusMeters: true,
            priority: true,
            _count: {
              select: { vendorAssignments: true, cars: true },
            },
          },
          orderBy: [{ priority: 'desc' }, { name: 'asc' }],
        },
        _count: {
          select: { serviceAreas: true },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  // 4. Admin: create city
  async create(
    dto: {
      name: string;
      state: string;
      latitude: number;
      longitude: number;
      isActive?: boolean;
      enabledTripTypes?: string[];
    },
    adminUserId: string,
  ) {
    const city = await this.prisma.supportedCity.create({
      data: {
        name: dto.name,
        state: dto.state,
        latitude: dto.latitude,
        longitude: dto.longitude,
        isActive: dto.isActive ?? true,
        enabledTripTypes: dto.enabledTripTypes ?? [],
      },
    });

    await this.auditLogService.log(
      adminUserId,
      'SUPPORTED_CITY_CREATED',
      'SupportedCity',
      city.id,
      dto,
    );
    return city;
  }

  // 5. Admin: update city
  async update(
    id: string,
    dto: {
      name?: string;
      state?: string;
      latitude?: number;
      longitude?: number;
      isActive?: boolean;
      enabledTripTypes?: string[];
    },
    adminUserId: string,
  ) {
    const existing = await this.prisma.supportedCity.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Supported city not found.');
    }

    const city = await this.prisma.supportedCity.update({
      where: { id },
      data: dto,
    });

    await this.auditLogService.log(
      adminUserId,
      'SUPPORTED_CITY_UPDATED',
      'SupportedCity',
      city.id,
      dto,
    );
    return city;
  }

  // 6. Admin: delete city
  async delete(id: string, adminUserId: string) {
    const existing = await this.prisma.supportedCity.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Supported city not found.');
    }

    const city = await this.prisma.supportedCity.delete({
      where: { id },
    });

    await this.auditLogService.log(
      adminUserId,
      'SUPPORTED_CITY_DELETED',
      'SupportedCity',
      id,
      {},
    );
    return { success: true, message: 'Supported city deleted successfully.' };
  }

  // 7. Admin: get service areas for city
  async getCityServiceAreas(cityId: string) {
    return this.prisma.serviceArea.findMany({
      where: { cityId },
      include: {
        _count: {
          select: { vendorAssignments: true, cars: true },
        },
      },
      orderBy: [{ priority: 'desc' }, { name: 'asc' }],
    });
  }

  // 8. Admin: get city readiness
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
    const activeAreas = city.serviceAreas.filter((a) => a.status === 'ACTIVE').length;
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

  // 9. Admin: get city impact
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
    const allVendorIds = Array.from(
      new Set(city.serviceAreas.flatMap((a) => a.vendorAssignments.map((v) => v.vendorId))),
    );

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
          status: 'ACTIVE',
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
        activeRentalsCount > 0
          ? `Alert: ${activeRentalsCount} active rentals are currently ongoing in ${city.name}.`
          : 'No active rentals currently in progress.',
      ],
    };
  }
}
