import { Injectable, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';
import {
  VehicleClass,
  VehicleFuelType,
  TransmissionType,
  FleetOperationalState,
} from './fleet-domain.types';
import { FleetAvailabilityService } from './fleet-availability.service';

export class FleetSearchFilters {
  query?: string;
  city?: string;
  branchId?: string;
  vehicleClass?: VehicleClass;
  make?: string;
  model?: string;
  fuelType?: VehicleFuelType;
  transmission?: TransmissionType;
  minSeating?: number;
  maxPricePerDay?: number;
  startDate?: string;
  endDate?: string;
  operationalState?: FleetOperationalState;
  limit?: number;
  offset?: number;
}

export interface FleetSearchResultItem {
  carId: string;
  make: string;
  model: string;
  year: number;
  vehicleClass: string;
  fuelType: string;
  seating: number;
  pricePerDay: number;
  pricePerHour: number;
  branchId: string;
  branchName: string;
  city: string;
  photos: string[];
  isAvailable: boolean;
  score?: number;
}

@Injectable()
export class FleetSearchService {
  private readonly logger = new Logger(FleetSearchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly availabilityService: FleetAvailabilityService,
    @Optional() private readonly runtimeService?: IntegrationRuntimeService,
  ) {}

  /**
   * Dispatches enterprise vehicle search with multi-faceted filtering.
   * Leverages IntegrationRuntime (Meilisearch / Search pack) with seamless Postgres DB fallback.
   */
  async searchFleet(filters: FleetSearchFilters): Promise<{
    items: FleetSearchResultItem[];
    total: number;
    searchProvider: string;
  }> {
    // 1. Attempt delegated search via IntegrationRuntimeService
    if (this.runtimeService && filters.query) {
      try {
        const searchRes = await this.runtimeService.execute<any, any>({
          category: IntegrationCategory.SEARCH,
          capability: 'SEARCH',
          payload: {
            index: 'vehicles',
            query: filters.query,
            filters: {
              city: filters.city,
              category: filters.vehicleClass,
            },
            limit: filters.limit || 20,
          },
        });

        if (searchRes.success && searchRes.data && Array.isArray(searchRes.data.hits)) {
          const hits: FleetSearchResultItem[] = searchRes.data.hits.map((h: any) => ({
            carId: h.id || h.carId,
            make: h.make || 'Toyota',
            model: h.model || 'Innova',
            year: h.year || 2024,
            vehicleClass: h.type || 'SUV',
            fuelType: h.fuelType || 'DIESEL',
            seating: h.seating || 7,
            pricePerDay: Number(h.pricePerDay || 3500),
            pricePerHour: Number(h.pricePerHour || 250),
            branchId: h.pickupHubId || 'branch_1',
            branchName: h.branchName || 'Central Hub',
            city: h.city || filters.city || 'Bengaluru',
            photos: h.photos || [],
            isAvailable: true,
            score: h.score,
          }));

          return {
            items: hits,
            total: searchRes.data.totalHits || hits.length,
            searchProvider: searchRes.providerId || 'meilisearch',
          };
        }
      } catch (err: any) {
        this.logger.warn(`Enterprise search runtime error, falling back to PostgreSQL query: ${err.message}`);
      }
    }

    // 2. High-performance PostgreSQL relational search fallback
    const whereClause: any = {
      isAvailable: true,
    };

    if (filters.city) {
      whereClause.pickupHub = { city: { equals: filters.city, mode: 'insensitive' } };
    }
    if (filters.branchId) {
      whereClause.pickupHubId = filters.branchId;
    }
    if (filters.make) {
      whereClause.make = { equals: filters.make, mode: 'insensitive' };
    }
    if (filters.model) {
      whereClause.model = { equals: filters.model, mode: 'insensitive' };
    }
    if (filters.fuelType) {
      whereClause.fuelType = filters.fuelType as any;
    }
    if (filters.minSeating) {
      whereClause.seating = { gte: filters.minSeating };
    }
    if (filters.maxPricePerDay) {
      whereClause.pricePerDay = { lte: filters.maxPricePerDay };
    }
    if (filters.query) {
      whereClause.OR = [
        { make: { contains: filters.query, mode: 'insensitive' } },
        { model: { contains: filters.query, mode: 'insensitive' } },
        { registrationNumber: { contains: filters.query, mode: 'insensitive' } },
      ];
    }

    const [total, cars] = await Promise.all([
      this.prisma.car.count({ where: whereClause }),
      this.prisma.car.findMany({
        where: whereClause,
        include: { pickupHub: true },
        take: filters.limit || 20,
        skip: filters.offset || 0,
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    // Check date interval availability if requested
    const items: FleetSearchResultItem[] = [];
    for (const c of cars) {
      let isAvailableForDates = true;
      if (filters.startDate && filters.endDate) {
        const avail = await this.availabilityService.explainAvailability(c.id, {
          startDate: new Date(filters.startDate),
          endDate: new Date(filters.endDate),
        });
        isAvailableForDates = avail.isAvailable;
      }

      items.push({
        carId: c.id,
        make: c.make,
        model: c.model,
        year: c.year,
        vehicleClass: c.type,
        fuelType: c.fuelType,
        seating: c.seating,
        pricePerDay: Number(c.pricePerDay),
        pricePerHour: Number(c.pricePerHour),
        branchId: c.pickupHubId || 'platform',
        branchName: c.pickupHub?.name || 'Central Yard',
        city: c.pickupHub?.city || 'Default City',
        photos: c.photos,
        isAvailable: isAvailableForDates,
      });
    }

    return {
      items,
      total,
      searchProvider: 'postgresql_relational',
    };
  }
}
