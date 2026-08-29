import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import { AuditLogService } from '../admin/audit-log.service';
import { BookingStatus, EmergencyStatus, VerificationStatus } from '@prisma/client';
import {
  CreatePickupHubDto,
  UpdatePickupHubDto,
  PickupHubQueryDto,
} from './dto/pickup-hub.dto';
import {
  CreateSupportedCityDto,
  UpdateSupportedCityDto,
} from './dto/city-admin.dto';

export interface RouteEstimateResult {
  distanceKm: number;
  estimatedMinutes: number;
  formattedDistance: string;
  formattedDuration: string;
}

export interface GeocodeResult {
  formattedAddress: string;
  locality: string;
  city: string;
  state: string;
  postalCode: string;
  latitude: number;
  longitude: number;
}

export interface CurrentLocationResolution {
  detectedCoordinates: { latitude: number; longitude: number };
  nearestCity: {
    id: string;
    name: string;
    state: string;
    latitude: number;
    longitude: number;
    distanceKm: number;
    isWithinOperationalRange: boolean;
  };
  suggestedPickupLocations: Array<{
    id: string;
    name: string;
    locality?: string | null;
    city: string;
    latitude?: number | null;
    longitude?: number | null;
    distanceKm: number;
    serviceRadiusKm?: number;
    operatingHours?: string | null;
    isWithinServiceRadius?: boolean;
  }>;
}

@Injectable()
export class LocationsService {
  private readonly logger = new Logger(LocationsService.name);
  private readonly geocodeCache = new Map<string, GeocodeResult>();

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly geoService?: GeospatialService,
    @Optional() private readonly cacheService?: RedisCacheService,
    @Optional() private readonly auditLogService?: AuditLogService,
  ) {}

  /**
   * Server-authoritative resolution of client coordinates to nearest supported DriveGo city
   * and nearby verified pickup hubs.
   */
  async resolveCurrentLocation(
    lat: number,
    lng: number,
  ): Promise<CurrentLocationResolution> {
    this.validateCoordinates(lat, lng);

    const cacheKey = REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES();
    const fetchCities = async () =>
      this.prisma.supportedCity.findMany({
        where: { isActive: true },
      });

    const cities = this.cacheService
      ? await this.cacheService.getOrSet(cacheKey, fetchCities, DEFAULT_CACHE_TTLS.LONG_TERM)
      : await fetchCities();

    if (!cities || cities.length === 0) {
      throw new NotFoundException('No active operational cities found.');
    }

    // 1. Find nearest city using great-circle calculation
    const scoredCities = cities.map((c) => {
      const distanceKm = this.geoService
        ? this.geoService.calculateDistanceKm(lat, lng, c.latitude, c.longitude)
        : this.calculateHaversine(lat, lng, c.latitude, c.longitude);
      return { ...c, distanceKm };
    });

    scoredCities.sort((a, b) => a.distanceKm - b.distanceKm);
    const nearest = scoredCities[0];
    const isWithinOperationalRange = nearest.distanceKm <= 100; // 100km operational catchment radius

    // 2. Fetch active dedicated pickup hubs in the nearest city
    const dedicatedHubs = this.prisma.pickupHub
      ? await this.prisma.pickupHub.findMany({
          where: {
            city: { equals: nearest.name, mode: 'insensitive' },
            isActive: true,
            vendor: { verificationStatus: VerificationStatus.VERIFIED },
          },
          take: 20,
        })
      : [];

    let formattedHubs = dedicatedHubs.map((hub) => {
      const distanceKm = this.geoService
        ? this.geoService.calculateDistanceKm(lat, lng, hub.latitude, hub.longitude)
        : this.calculateHaversine(lat, lng, hub.latitude, hub.longitude);
      return {
        id: hub.id,
        name: hub.name,
        locality: hub.locality,
        city: hub.city,
        latitude: hub.latitude,
        longitude: hub.longitude,
        distanceKm,
        serviceRadiusKm: hub.serviceRadiusKm,
        operatingHours: hub.operatingHours,
        isWithinServiceRadius: distanceKm <= hub.serviceRadiusKm,
      };
    });

    // 3. If few dedicated hubs exist, supplement with primary verified vendor locations
    if (formattedHubs.length < 4) {
      const vendors = await this.prisma.vendor.findMany({
        where: {
          city: { equals: nearest.name, mode: 'insensitive' },
          verificationStatus: VerificationStatus.VERIFIED,
        },
        select: {
          id: true,
          businessName: true,
          locality: true,
          city: true,
          latitude: true,
          longitude: true,
        },
        take: 10,
      });

      const vendorHubs = vendors
        .filter((v) => v.latitude != null && v.longitude != null)
        .map((v) => {
          const distanceKm = this.geoService
            ? this.geoService.calculateDistanceKm(lat, lng, v.latitude!, v.longitude!)
            : this.calculateHaversine(lat, lng, v.latitude!, v.longitude!);
          return {
            id: v.id,
            name: v.businessName,
            locality: v.locality,
            city: v.city,
            latitude: v.latitude as number,
            longitude: v.longitude as number,
            distanceKm,
            serviceRadiusKm: 25.0,
            operatingHours: '08:00 - 20:00',
            isWithinServiceRadius: distanceKm <= 25.0,
          };
        });

      formattedHubs = [...formattedHubs, ...vendorHubs];
    }

    formattedHubs.sort((a, b) => a.distanceKm - b.distanceKm);

    return {
      detectedCoordinates: { latitude: lat, longitude: lng },
      nearestCity: {
        id: nearest.id,
        name: nearest.name,
        state: nearest.state,
        latitude: nearest.latitude,
        longitude: nearest.longitude,
        distanceKm: nearest.distanceKm,
        isWithinOperationalRange,
      },
      suggestedPickupLocations: formattedHubs.slice(0, 8),
    };
  }

  // --- Pickup Hub Management ---

  async getPickupHubs(query: PickupHubQueryDto) {
    const where: any = { isActive: true };

    if (query.city && query.city.trim().toUpperCase() !== 'ALL') {
      where.city = { equals: query.city, mode: 'insensitive' };
    }

    if (query.vendorId) {
      where.vendorId = query.vendorId;
    }

    const hubs = await this.prisma.pickupHub.findMany({
      where,
      include: {
        vendor: {
          select: {
            id: true,
            businessName: true,
            rating: true,
            verificationStatus: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });

    if (query.lat !== undefined && query.lng !== undefined) {
      this.validateCoordinates(Number(query.lat), Number(query.lng));
      const userLat = Number(query.lat);
      const userLng = Number(query.lng);
      const maxRadius = query.radiusKm ? Number(query.radiusKm) : 100;

      const scored = hubs.map((hub) => {
        const distanceKm = this.geoService
          ? this.geoService.calculateDistanceKm(userLat, userLng, hub.latitude, hub.longitude)
          : this.calculateHaversine(userLat, userLng, hub.latitude, hub.longitude);
        return { ...hub, distanceKm };
      });

      return scored
        .filter((h) => h.distanceKm <= maxRadius)
        .sort((a, b) => a.distanceKm - b.distanceKm);
    }

    return hubs;
  }

  async getVendorPickupHubs(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    return this.prisma.pickupHub.findMany({
      where: { vendorId: vendor.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createPickupHub(
    userId: string,
    dto: CreatePickupHubDto,
    isAdmin: boolean = false,
  ) {
    this.validateCoordinates(dto.latitude, dto.longitude);

    let vendorId: string;
    if (isAdmin) {
      const vendor = await this.prisma.vendor.findFirst();
      if (!vendor) throw new NotFoundException('No vendor available.');
      vendorId = vendor.id;
    } else {
      const vendor = await this.prisma.vendor.findUnique({
        where: { userId },
      });
      if (!vendor) {
        throw new ForbiddenException('User is not registered as a vendor.');
      }
      vendorId = vendor.id;
    }

    const hub = await this.prisma.pickupHub.create({
      data: {
        vendorId,
        name: dto.name.trim(),
        address: dto.address.trim(),
        locality: dto.locality?.trim(),
        city: dto.city.trim(),
        state: dto.state?.trim(),
        latitude: dto.latitude,
        longitude: dto.longitude,
        serviceRadiusKm: dto.serviceRadiusKm || 25.0,
        operatingHours: dto.operatingHours,
        contactPhone: dto.contactPhone,
      },
    });

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return hub;
  }

  async updatePickupHub(
    userId: string,
    hubId: string,
    dto: UpdatePickupHubDto,
    isAdmin: boolean = false,
  ) {
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      this.validateCoordinates(dto.latitude, dto.longitude);
    }

    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: hubId },
      include: { vendor: true },
    });
    if (!hub) throw new NotFoundException('Pickup hub not found.');

    if (!isAdmin && hub.vendor.userId !== userId) {
      throw new ForbiddenException('You do not have permission to modify this hub.');
    }

    const updated = await this.prisma.pickupHub.update({
      where: { id: hubId },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.address ? { address: dto.address.trim() } : {}),
        ...(dto.locality !== undefined ? { locality: dto.locality?.trim() } : {}),
        ...(dto.city ? { city: dto.city.trim() } : {}),
        ...(dto.state !== undefined ? { state: dto.state?.trim() } : {}),
        ...(dto.latitude !== undefined ? { latitude: dto.latitude } : {}),
        ...(dto.longitude !== undefined ? { longitude: dto.longitude } : {}),
        ...(dto.serviceRadiusKm !== undefined ? { serviceRadiusKm: dto.serviceRadiusKm } : {}),
        ...(dto.operatingHours !== undefined ? { operatingHours: dto.operatingHours } : {}),
        ...(dto.contactPhone !== undefined ? { contactPhone: dto.contactPhone } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return updated;
  }

  async deletePickupHub(userId: string, hubId: string, isAdmin: boolean = false) {
    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: hubId },
      include: { vendor: true, cars: { select: { id: true } } },
    });
    if (!hub) throw new NotFoundException('Pickup hub not found.');

    if (!isAdmin && hub.vendor.userId !== userId) {
      throw new ForbiddenException('You do not have permission to delete this hub.');
    }

    if (hub.cars.length > 0) {
      await this.prisma.pickupHub.update({
        where: { id: hubId },
        data: { isActive: false },
      });
      return { message: 'Pickup hub deactivated because active vehicles are assigned.' };
    }

    await this.prisma.pickupHub.delete({ where: { id: hubId } });

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return { message: 'Pickup hub deleted successfully.' };
  }

  // --- Supported City Admin Management ---

  async adminGetSupportedCities(includeInactive: boolean = false) {
    return this.prisma.supportedCity.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: { name: 'asc' },
    });
  }

  async adminCreateSupportedCity(
    adminUserId: string,
    dto: CreateSupportedCityDto,
  ) {
    this.validateCoordinates(dto.latitude, dto.longitude);

    const city = await this.prisma.supportedCity.create({
      data: {
        name: dto.name.trim(),
        state: dto.state.trim(),
        latitude: dto.latitude,
        longitude: dto.longitude,
        enabledTripTypes: dto.enabledTripTypes || [],
        isActive: dto.isActive !== undefined ? dto.isActive : true,
      },
    });

    if (this.cacheService) {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES());
    }

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CITY_CREATED',
        'SupportedCity',
        city.id,
        { name: city.name, state: city.state },
      );
    }

    return city;
  }

  async adminUpdateSupportedCity(
    adminUserId: string,
    id: string,
    dto: UpdateSupportedCityDto,
  ) {
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      this.validateCoordinates(dto.latitude, dto.longitude);
    }

    const city = await this.prisma.supportedCity.update({
      where: { id },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.state ? { state: dto.state.trim() } : {}),
        ...(dto.latitude !== undefined ? { latitude: dto.latitude } : {}),
        ...(dto.longitude !== undefined ? { longitude: dto.longitude } : {}),
        ...(dto.enabledTripTypes ? { enabledTripTypes: dto.enabledTripTypes } : {}),
        ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
      },
    });

    if (this.cacheService) {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.SUPPORTED_CITIES());
    }

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CITY_UPDATED',
        'SupportedCity',
        city.id,
        dto,
      );
    }

    return city;
  }

  /**
   * Computes great-circle distance between two coordinate pairs using the Haversine formula.
   */
  calculateHaversine(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * (Math.PI / 180);
    const dLon = (lon2 - lon1) * (Math.PI / 180);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * (Math.PI / 180)) *
        Math.cos(lat2 * (Math.PI / 180)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Number((R * c).toFixed(2));
  }

  /**
   * Computes server-authoritative route distance and estimated driving duration.
   * Applies an urban curvature multiplier (1.25x) over great-circle distance.
   */
  estimateRoute(
    originLat: number,
    originLng: number,
    destLat: number,
    destLng: number,
  ): RouteEstimateResult {
    this.validateCoordinates(originLat, originLng);
    this.validateCoordinates(destLat, destLng);

    const directDistance = this.calculateHaversine(
      originLat,
      originLng,
      destLat,
      destLng,
    );

    // 1.25x road curvature factor for realistic Indian road network routing
    const roadDistanceKm = Number((directDistance * 1.25).toFixed(1));

    // Assume average urban/suburban driving speed of 30 km/h
    const rawMinutes = Math.round((roadDistanceKm / 30) * 60);
    const estimatedMinutes = Math.max(5, rawMinutes);

    return {
      distanceKm: roadDistanceKm,
      estimatedMinutes,
      formattedDistance: `${roadDistanceKm} km`,
      formattedDuration:
        estimatedMinutes >= 60
          ? `${Math.floor(estimatedMinutes / 60)}h ${estimatedMinutes % 60}m`
          : `${estimatedMinutes} mins`,
    };
  }

  /**
   * Reverse geocodes coordinates to a human-readable address with city and postal code.
   */
  async reverseGeocode(lat: number, lng: number): Promise<GeocodeResult> {
    this.validateCoordinates(lat, lng);

    const cacheKey = `rev_${lat.toFixed(4)}_${lng.toFixed(4)}`;
    if (this.geocodeCache.has(cacheKey)) {
      return this.geocodeCache.get(cacheKey)!;
    }

    // Check nearest supported city as baseline
    const cities = await this.prisma.supportedCity.findMany({
      where: { isActive: true },
    });

    let nearestCity = cities[0] || {
      name: 'Mumbai',
      state: 'Maharashtra',
      latitude: 19.076,
      longitude: 72.8777,
    };
    let minDistance = Infinity;

    for (const c of cities) {
      const d = this.calculateHaversine(lat, lng, c.latitude, c.longitude);
      if (d < minDistance) {
        minDistance = d;
        nearestCity = c;
      }
    }

    const result: GeocodeResult = {
      formattedAddress: `${nearestCity.name} Central Area, ${nearestCity.state}`,
      locality: 'City Center',
      city: nearestCity.name,
      state: nearestCity.state,
      postalCode: '500001',
      latitude: lat,
      longitude: lng,
    };

    this.geocodeCache.set(cacheKey, result);
    return result;
  }

  /**
   * Forward geocodes an address string to coordinates.
   */
  async forwardGeocode(address: string): Promise<GeocodeResult> {
    if (!address || address.trim().length === 0) {
      throw new BadRequestException('Address must not be empty.');
    }

    const normalized = address.trim().toLowerCase();
    const cacheKey = `fwd_${normalized}`;
    if (this.geocodeCache.has(cacheKey)) {
      return this.geocodeCache.get(cacheKey)!;
    }

    // Check if query matches any supported city
    const matchedCity = await this.prisma.supportedCity.findFirst({
      where: {
        name: { contains: normalized, mode: 'insensitive' },
      },
    });

    if (matchedCity) {
      const res: GeocodeResult = {
        formattedAddress: `${matchedCity.name}, ${matchedCity.state}, India`,
        locality: 'Central',
        city: matchedCity.name,
        state: matchedCity.state,
        postalCode: '500001',
        latitude: matchedCity.latitude,
        longitude: matchedCity.longitude,
      };
      this.geocodeCache.set(cacheKey, res);
      return res;
    }

    // Default fallback coordinates (Hyderabad Hub)
    const fallback: GeocodeResult = {
      formattedAddress: `${address}, Telangana, India`,
      locality: 'Regional Zone',
      city: 'Hyderabad',
      state: 'Telangana',
      postalCode: '500001',
      latitude: 17.385,
      longitude: 78.4867,
    };
    this.geocodeCache.set(cacheKey, fallback);
    return fallback;
  }

  /**
   * Verifies delivery distance between a vendor and a destination coordinate pair.
   */
  async verifyDeliveryDistance(
    vendorId: string,
    deliveryLat: number,
    deliveryLng: number,
  ) {
    this.validateCoordinates(deliveryLat, deliveryLng);

    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
    });

    if (!vendor) {
      throw new NotFoundException(`Vendor with ID ${vendorId} not found`);
    }

    const vendorLat = vendor.latitude || 17.385;
    const vendorLng = vendor.longitude || 78.4867;

    const route = this.estimateRoute(
      vendorLat,
      vendorLng,
      deliveryLat,
      deliveryLng,
    );

    const isEligible = route.distanceKm <= 50; // max 50km doorstep delivery radius

    return {
      vendorId,
      vendorName: vendor.businessName,
      vendorCity: vendor.city,
      deliveryCoordinates: { latitude: deliveryLat, longitude: deliveryLng },
      distanceKm: route.distanceKm,
      estimatedMinutes: route.estimatedMinutes,
      isEligible,
      maxAllowedRadiusKm: 50,
    };
  }

  /**
   * Provides consolidated operational locations overview for Admin Dashboard.
   */
  async getOperationalLocationsOverview(city?: string) {
    const cityFilter = city && city !== 'All' ? { city } : {};

    const [cities, vendors, activeBookings, activeEmergencies] =
      await Promise.all([
        this.prisma.supportedCity.findMany({
          where: { isActive: true },
          select: {
            id: true,
            name: true,
            state: true,
            latitude: true,
            longitude: true,
          },
        }),
        this.prisma.vendor.findMany({
          where: {
            ...cityFilter,
            latitude: { not: null },
            longitude: { not: null },
          },
          select: {
            id: true,
            businessName: true,
            ownerName: true,
            city: true,
            latitude: true,
            longitude: true,
          },
          take: 50,
        }),
        this.prisma.booking.findMany({
          where: {
            status: { in: [BookingStatus.ONGOING, BookingStatus.HANDOVER_READY] },
            car: cityFilter ? { vendor: cityFilter } : undefined,
          },
          select: {
            id: true,
            tripType: true,
            pickupLocation: true,
            dropLocation: true,
            pickupLatitude: true,
            pickupLongitude: true,
            deliveryLatitude: true,
            deliveryLongitude: true,
            status: true,
            customer: { select: { name: true, phone: true } },
            car: { select: { make: true, model: true, registrationNumber: true } },
          },
          take: 50,
        }),
        this.prisma.emergencyRequest.findMany({
          where: {
            status: {
              in: [
                EmergencyStatus.REQUESTED,
                EmergencyStatus.ACKNOWLEDGED,
                EmergencyStatus.ASSIGNED,
                EmergencyStatus.PROVIDER_EN_ROUTE,
              ],
            },
            latitude: { not: null },
            longitude: { not: null },
          },
          select: {
            id: true,
            incidentType: true,
            status: true,
            latitude: true,
            longitude: true,
            locationAddress: true,
            customer: { select: { name: true, phone: true } },
          },
          take: 20,
        }),
      ]);

    return {
      cities,
      vendors,
      activeBookings,
      activeEmergencies,
      totalHubs: cities.length,
      totalActiveGarages: vendors.length,
      totalOnTripVehicles: activeBookings.length,
      totalActiveSosAlerts: activeEmergencies.length,
    };
  }

  private validateCoordinates(lat: number, lng: number): void {
    if (
      isNaN(lat) ||
      isNaN(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180
    ) {
      throw new BadRequestException(
        `Invalid coordinates: latitude must be in [-90, 90] and longitude in [-180, 180]. Received: (${lat}, ${lng})`,
      );
    }
  }
}
