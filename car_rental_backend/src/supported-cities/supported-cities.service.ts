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

  // 3. Admin: find all cities (including inactive)
  async findAllAdmin() {
    return this.prisma.supportedCity.findMany({
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
}
