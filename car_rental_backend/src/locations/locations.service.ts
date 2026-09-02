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
import {
  CreateVendorLocationDto,
  UpdateVendorLocationDto,
  UpdateVendorDeliveryPolicyDto,
  CalculateDeliveryQuoteDto,
  UpdateLocationMatrixDto,
  CreateLocationExceptionDto,
  VendorLocationTypeEnum,
  VendorLocationStatusEnum,
  DeliveryPricingModelEnum,
} from './dto/vendor-location-operations.dto';

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

  // --- Vendor Location Operations (Phase 29.11) ---

  private parseLocationMetadata(hub: any) {
    let meta: any = {};
    if (hub.operatingHours && hub.operatingHours.startsWith('{')) {
      try {
        meta = JSON.parse(hub.operatingHours);
      } catch (e) {
        meta = {};
      }
    }
    return {
      id: hub.id,
      vendorId: hub.vendorId,
      name: hub.name,
      type: meta.type || VendorLocationTypeEnum.VENDOR_YARD,
      address: hub.address,
      locality: hub.locality || null,
      city: hub.city,
      state: hub.state || null,
      pincode: meta.pincode || null,
      latitude: hub.latitude,
      longitude: hub.longitude,
      contactPerson: meta.contactPerson || null,
      contactPhone: hub.contactPhone || meta.contactPhone || null,
      status: meta.status || (hub.isActive ? VendorLocationStatusEnum.ACTIVE : VendorLocationStatusEnum.INACTIVE),
      allowsPickup: meta.allowsPickup !== undefined ? meta.allowsPickup : true,
      allowsReturn: meta.allowsReturn !== undefined ? meta.allowsReturn : true,
      allowsDelivery: meta.allowsDelivery !== undefined ? meta.allowsDelivery : false,
      pickupFee: meta.pickupFee !== undefined ? meta.pickupFee : 0,
      returnFee: meta.returnFee !== undefined ? meta.returnFee : 0,
      oneWayFee: meta.oneWayFee !== undefined ? meta.oneWayFee : 0,
      openingTime: meta.openingTime || '08:00',
      closingTime: meta.closingTime || '22:00',
      is24x7: meta.is24x7 !== undefined ? meta.is24x7 : false,
      serviceRadiusKm: hub.serviceRadiusKm || 25.0,
      assignedCarCount: hub.cars ? hub.cars.length : (meta.assignedCarIds ? meta.assignedCarIds.length : 0),
      assignedCarIds: hub.cars ? hub.cars.map((c: any) => c.id) : (meta.assignedCarIds || []),
      createdAt: hub.createdAt,
      updatedAt: hub.updatedAt,
    };
  }

  async getVendorLocations(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const hubs = await this.prisma.pickupHub.findMany({
      where: { vendorId: vendor.id },
      include: { cars: { select: { id: true, make: true, model: true, registrationNumber: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return hubs.map((h) => this.parseLocationMetadata(h));
  }

  async createVendorLocation(userId: string, dto: CreateVendorLocationDto) {
    this.validateCoordinates(dto.latitude, dto.longitude);

    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const meta = {
      type: dto.type || VendorLocationTypeEnum.VENDOR_YARD,
      status: VendorLocationStatusEnum.ACTIVE,
      pincode: dto.pincode,
      contactPerson: dto.contactPerson,
      allowsPickup: dto.allowsPickup !== undefined ? dto.allowsPickup : true,
      allowsReturn: dto.allowsReturn !== undefined ? dto.allowsReturn : true,
      allowsDelivery: dto.allowsDelivery !== undefined ? dto.allowsDelivery : false,
      pickupFee: dto.pickupFee || 0,
      returnFee: dto.returnFee || 0,
      oneWayFee: dto.oneWayFee || 0,
      openingTime: dto.openingTime || '08:00',
      closingTime: dto.closingTime || '22:00',
      is24x7: dto.is24x7 !== undefined ? dto.is24x7 : false,
      assignedCarIds: dto.assignedCarIds || [],
    };

    const hub = await this.prisma.pickupHub.create({
      data: {
        vendorId: vendor.id,
        name: dto.name.trim(),
        address: dto.address.trim(),
        locality: dto.locality?.trim(),
        city: dto.city.trim(),
        state: dto.state?.trim(),
        latitude: dto.latitude,
        longitude: dto.longitude,
        serviceRadiusKm: dto.serviceRadiusKm || 25.0,
        operatingHours: JSON.stringify(meta),
        contactPhone: dto.contactPhone,
        isActive: true,
      },
      include: { cars: { select: { id: true, make: true, model: true, registrationNumber: true } } },
    });

    if (dto.assignedCarIds && dto.assignedCarIds.length > 0) {
      await this.prisma.car.updateMany({
        where: { id: { in: dto.assignedCarIds }, vendorId: vendor.id },
        data: { pickupHubId: hub.id },
      });
    }

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return this.parseLocationMetadata(hub);
  }

  async getVendorLocationById(userId: string, locationId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: locationId },
      include: { cars: { select: { id: true, make: true, model: true, registrationNumber: true } } },
    });
    if (!hub) throw new NotFoundException('Location not found.');
    if (hub.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not own this location.');
    }

    return this.parseLocationMetadata(hub);
  }

  async updateVendorLocation(userId: string, locationId: string, dto: UpdateVendorLocationDto) {
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      this.validateCoordinates(dto.latitude, dto.longitude);
    }

    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: locationId },
      include: { cars: { select: { id: true } } },
    });
    if (!hub) throw new NotFoundException('Location not found.');
    if (hub.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not own this location.');
    }

    let existingMeta: any = {};
    if (hub.operatingHours && hub.operatingHours.startsWith('{')) {
      try {
        existingMeta = JSON.parse(hub.operatingHours);
      } catch (e) {
        existingMeta = {};
      }
    }

    const updatedMeta = {
      ...existingMeta,
      ...(dto.type !== undefined ? { type: dto.type } : {}),
      ...(dto.status !== undefined ? { status: dto.status } : {}),
      ...(dto.pincode !== undefined ? { pincode: dto.pincode } : {}),
      ...(dto.contactPerson !== undefined ? { contactPerson: dto.contactPerson } : {}),
      ...(dto.allowsPickup !== undefined ? { allowsPickup: dto.allowsPickup } : {}),
      ...(dto.allowsReturn !== undefined ? { allowsReturn: dto.allowsReturn } : {}),
      ...(dto.allowsDelivery !== undefined ? { allowsDelivery: dto.allowsDelivery } : {}),
      ...(dto.pickupFee !== undefined ? { pickupFee: dto.pickupFee } : {}),
      ...(dto.returnFee !== undefined ? { returnFee: dto.returnFee } : {}),
      ...(dto.oneWayFee !== undefined ? { oneWayFee: dto.oneWayFee } : {}),
      ...(dto.openingTime !== undefined ? { openingTime: dto.openingTime } : {}),
      ...(dto.closingTime !== undefined ? { closingTime: dto.closingTime } : {}),
      ...(dto.is24x7 !== undefined ? { is24x7: dto.is24x7 } : {}),
      ...(dto.assignedCarIds !== undefined ? { assignedCarIds: dto.assignedCarIds } : {}),
    };

    const updated = await this.prisma.pickupHub.update({
      where: { id: locationId },
      data: {
        ...(dto.name ? { name: dto.name.trim() } : {}),
        ...(dto.address ? { address: dto.address.trim() } : {}),
        ...(dto.locality !== undefined ? { locality: dto.locality?.trim() } : {}),
        ...(dto.city ? { city: dto.city.trim() } : {}),
        ...(dto.state !== undefined ? { state: dto.state?.trim() } : {}),
        ...(dto.latitude !== undefined ? { latitude: dto.latitude } : {}),
        ...(dto.longitude !== undefined ? { longitude: dto.longitude } : {}),
        ...(dto.serviceRadiusKm !== undefined ? { serviceRadiusKm: dto.serviceRadiusKm } : {}),
        ...(dto.contactPhone !== undefined ? { contactPhone: dto.contactPhone } : {}),
        ...(dto.status !== undefined ? { isActive: dto.status === VendorLocationStatusEnum.ACTIVE } : {}),
        operatingHours: JSON.stringify(updatedMeta),
      },
      include: { cars: { select: { id: true, make: true, model: true, registrationNumber: true } } },
    });

    if (dto.assignedCarIds !== undefined) {
      await this.prisma.car.updateMany({
        where: { pickupHubId: locationId, vendorId: vendor.id },
        data: { pickupHubId: null },
      });
      if (dto.assignedCarIds.length > 0) {
        await this.prisma.car.updateMany({
          where: { id: { in: dto.assignedCarIds }, vendorId: vendor.id },
          data: { pickupHubId: locationId },
        });
      }
    }

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return this.parseLocationMetadata(updated);
  }

  async deleteVendorLocation(userId: string, locationId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: locationId },
      include: { cars: { select: { id: true } } },
    });
    if (!hub) throw new NotFoundException('Location not found.');
    if (hub.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not own this location.');
    }

    // Soft-deactivate if vehicles exist, or delete
    if (hub.cars.length > 0) {
      let meta: any = {};
      if (hub.operatingHours && hub.operatingHours.startsWith('{')) {
        try {
          meta = JSON.parse(hub.operatingHours);
        } catch (e) {
          meta = {};
        }
      }
      meta.status = VendorLocationStatusEnum.INACTIVE;

      await this.prisma.pickupHub.update({
        where: { id: locationId },
        data: { isActive: false, operatingHours: JSON.stringify(meta) },
      });
      return { message: 'Location deactivated because active vehicles are assigned.' };
    }

    await this.prisma.pickupHub.delete({ where: { id: locationId } });

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    return { message: 'Location deleted successfully.' };
  }

  async getVendorDeliveryPolicy(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const cacheKey = `vendor:delivery-policy:${vendor.id}`;
    if (this.cacheService) {
      const cached = await this.cacheService.get(cacheKey);
      if (cached) return cached;
    }

    let policy = await this.prisma.vendorDeliveryPolicy.findUnique({
      where: { vendorId: vendor.id },
    });

    if (!policy) {
      policy = await this.prisma.vendorDeliveryPolicy.create({
        data: {
          vendorId: vendor.id,
          deliveryEnabled: true,
          maxDeliveryRadiusKm: 25.0,
          pricingModel: 'DISTANCE_BASED',
          baseDeliveryFee: 100.0,
          perKmDeliveryFee: 20.0,
          freeDeliveryWithinKm: 5.0,
        },
      });
    }

    const formatted = {
      vendorId: policy.vendorId,
      deliveryEnabled: policy.deliveryEnabled,
      maxDeliveryRadiusKm: policy.maxDeliveryRadiusKm,
      pricingModel: policy.pricingModel,
      baseDeliveryFee: Number(policy.baseDeliveryFee),
      perKmDeliveryFee: Number(policy.perKmDeliveryFee),
      freeDeliveryWithinKm: policy.freeDeliveryWithinKm,
    };

    if (this.cacheService) {
      await this.cacheService.set(cacheKey, formatted, DEFAULT_CACHE_TTLS.LONG_TERM);
    }

    return formatted;
  }

  async updateVendorDeliveryPolicy(userId: string, dto: UpdateVendorDeliveryPolicyDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const current = await this.getVendorDeliveryPolicy(userId);
    const updated = await this.prisma.vendorDeliveryPolicy.upsert({
      where: { vendorId: vendor.id },
      update: {
        ...(dto.deliveryEnabled !== undefined ? { deliveryEnabled: dto.deliveryEnabled } : {}),
        ...(dto.maxDeliveryRadiusKm !== undefined ? { maxDeliveryRadiusKm: dto.maxDeliveryRadiusKm } : {}),
        ...(dto.pricingModel !== undefined ? { pricingModel: dto.pricingModel as any } : {}),
        ...(dto.baseDeliveryFee !== undefined ? { baseDeliveryFee: dto.baseDeliveryFee } : {}),
        ...(dto.perKmDeliveryFee !== undefined ? { perKmDeliveryFee: dto.perKmDeliveryFee } : {}),
        ...(dto.freeDeliveryWithinKm !== undefined ? { freeDeliveryWithinKm: dto.freeDeliveryWithinKm } : {}),
      },
      create: {
        vendorId: vendor.id,
        deliveryEnabled: dto.deliveryEnabled ?? true,
        maxDeliveryRadiusKm: dto.maxDeliveryRadiusKm ?? 25.0,
        pricingModel: (dto.pricingModel as any) ?? 'DISTANCE_BASED',
        baseDeliveryFee: dto.baseDeliveryFee ?? 100.0,
        perKmDeliveryFee: dto.perKmDeliveryFee ?? 20.0,
        freeDeliveryWithinKm: dto.freeDeliveryWithinKm ?? 5.0,
      },
    });

    const formatted = {
      vendorId: updated.vendorId,
      deliveryEnabled: updated.deliveryEnabled,
      maxDeliveryRadiusKm: updated.maxDeliveryRadiusKm,
      pricingModel: updated.pricingModel,
      baseDeliveryFee: Number(updated.baseDeliveryFee),
      perKmDeliveryFee: Number(updated.perKmDeliveryFee),
      freeDeliveryWithinKm: updated.freeDeliveryWithinKm,
    };

    const cacheKey = `vendor:delivery-policy:${vendor.id}`;
    if (this.cacheService) {
      await this.cacheService.set(cacheKey, formatted, DEFAULT_CACHE_TTLS.LONG_TERM);
    }

    if (this.auditLogService) {
      await this.auditLogService.log(
        userId,
        'VENDOR_DELIVERY_POLICY_UPDATE',
        'VendorDeliveryPolicy',
        updated.id,
        { before: current, after: formatted },
      );
    }

    return formatted;
  }

  async getVendorLocationMatrix(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const locations = await this.getVendorLocations(userId);
    const activeLocations = locations.filter((l: any) => l.status === VendorLocationStatusEnum.ACTIVE);

    const persisted = await this.prisma.vendorLocationMatrix.findMany({
      where: { vendorId: vendor.id },
    });

    const matrix: any[] = [];
    for (const pickup of activeLocations) {
      for (const returnLoc of activeLocations) {
        const isSame = pickup.id === returnLoc.id;
        const existing = persisted.find(
          (p) => p.pickupLocationId === pickup.id && p.returnLocationId === returnLoc.id,
        );
        const oneWaySurcharge = isSame
          ? 0.0
          : existing
            ? Number(existing.oneWaySurcharge)
            : (returnLoc.oneWayFee || pickup.oneWayFee || 250.0);
        const isSupported = isSame ? true : existing ? existing.isSupported : true;

        matrix.push({
          pickupLocationId: pickup.id,
          returnLocationId: returnLoc.id,
          pickupLocationName: pickup.name,
          returnLocationName: returnLoc.name,
          isSupported,
          oneWaySurcharge,
        });
      }
    }

    return matrix;
  }

  async updateVendorLocationMatrix(userId: string, dto: UpdateLocationMatrixDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    for (const item of dto.matrix) {
      await this.prisma.vendorLocationMatrix.upsert({
        where: {
          vendorId_pickupLocationId_returnLocationId: {
            vendorId: vendor.id,
            pickupLocationId: item.pickupLocationId,
            returnLocationId: item.returnLocationId,
          },
        },
        update: {
          isSupported: item.isSupported,
          oneWaySurcharge: item.oneWaySurcharge ?? 0,
        },
        create: {
          vendorId: vendor.id,
          pickupLocationId: item.pickupLocationId,
          returnLocationId: item.returnLocationId,
          isSupported: item.isSupported,
          oneWaySurcharge: item.oneWaySurcharge ?? 0,
        },
      });
    }

    const cacheKey = `vendor:location-matrix:${vendor.id}`;
    if (this.cacheService) {
      await this.cacheService.set(cacheKey, dto.matrix, DEFAULT_CACHE_TTLS.LONG_TERM);
    }

    if (this.auditLogService) {
      await this.auditLogService.log(
        userId,
        'VENDOR_LOCATION_MATRIX_UPDATE',
        'VendorLocationMatrix',
        vendor.id,
        { matrixCount: dto.matrix.length },
      );
    }

    return { message: 'Location matrix updated successfully.', matrix: dto.matrix };
  }

  async createLocationException(userId: string, locationId: string, dto: CreateLocationExceptionDto) {
    const vendor = await this.prisma.vendor.findUnique({ where: { userId } });
    if (!vendor) throw new ForbiddenException('User is not registered as a vendor.');

    const hub = await this.prisma.pickupHub.findUnique({ where: { id: locationId } });
    if (!hub) throw new NotFoundException('Location not found.');
    if (hub.vendorId !== vendor.id) throw new ForbiddenException('You do not own this location.');

    const exceptionDate = new Date(dto.date);
    const created = await this.prisma.locationException.create({
      data: {
        locationId,
        date: exceptionDate,
        exceptionType: (dto.exceptionType as any) || 'HOLIDAY',
        isClosed: dto.isClosed ?? true,
        customOpeningTime: dto.customOpeningTime,
        customClosingTime: dto.customClosingTime,
        reason: dto.reason,
      },
    });

    if (this.auditLogService) {
      await this.auditLogService.log(
        userId,
        'LOCATION_EXCEPTION_CREATED',
        'LocationException',
        created.id,
        { locationId, date: dto.date, reason: dto.reason },
      );
    }

    return created;
  }

  async getLocationExceptions(locationId: string) {
    return this.prisma.locationException.findMany({
      where: { locationId },
      orderBy: { date: 'asc' },
    });
  }

  async deleteLocationException(userId: string, exceptionId: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { userId } });
    if (!vendor) throw new ForbiddenException('User is not registered as a vendor.');

    const exc = await this.prisma.locationException.findUnique({
      where: { id: exceptionId },
      include: { location: true },
    });
    if (!exc) throw new NotFoundException('Location exception not found.');
    if (exc.location.vendorId !== vendor.id) throw new ForbiddenException('You do not own this location.');

    await this.prisma.locationException.delete({ where: { id: exceptionId } });
    return { message: 'Location exception deleted successfully.' };
  }

  async getVendorLocationOperationsSummary(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }

    const locations = await this.getVendorLocations(userId);

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);

    const todayBookings = await this.prisma.booking.findMany({
      where: {
        vendorId: vendor.id,
        OR: [
          { startDate: { gte: startOfToday, lte: endOfToday } },
          { endDate: { gte: startOfToday, lte: endOfToday } },
          { status: { in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY, BookingStatus.ONGOING] } },
        ],
      },
      select: {
        id: true,
        pickupLocation: true,
        dropLocation: true,
        status: true,
        deliveryType: true,
      },
    });

    const locationSummary = locations.map((loc: any) => {
      const todayPickups = todayBookings.filter(
        (b) => b.pickupLocation && b.pickupLocation.toLowerCase().includes(loc.name.toLowerCase()),
      ).length;
      const todayReturns = todayBookings.filter(
        (b) => b.dropLocation && b.dropLocation.toLowerCase().includes(loc.name.toLowerCase()),
      ).length;

      return {
        locationId: loc.id,
        locationName: loc.name,
        locationType: loc.type,
        todayPickups: todayPickups,
        todayReturns: todayReturns,
        activeVehicles: loc.assignedCarCount || 0,
      };
    });

    const totalDeliveryRequests = todayBookings.filter(
      (b) => b.deliveryType && b.deliveryType !== 'NONE',
    ).length;

    const totalTodayPickups = locationSummary.reduce((acc, l) => acc + l.todayPickups, 0);
    const totalTodayReturns = locationSummary.reduce((acc, l) => acc + l.todayReturns, 0);

    return {
      locations: locationSummary,
      totalTodayPickups,
      totalTodayReturns,
      totalDeliveryRequests,
    };
  }

  async getPublicLocationCatalog(city?: string) {
    let items = await this.prisma.publicTransportPoint.findMany({
      where: {
        isApproved: true,
        ...(city ? { city: { equals: city, mode: 'insensitive' } } : {}),
      },
    });

    if (items.length === 0) {
      const seedPoints = [
        {
          id: 'pub_hyd_rgia',
          name: 'Rajiv Gandhi International Airport (HYD)',
          type: 'AIRPORT' as any,
          city: 'Hyderabad',
          state: 'Telangana',
          locality: 'Shamshabad',
          latitude: 17.2403,
          longitude: 78.4294,
          category: 'Airport Terminal',
          isApproved: true,
        },
        {
          id: 'pub_hyd_secunderabad_rail',
          name: 'Secunderabad Junction Railway Station',
          type: 'RAILWAY_STATION' as any,
          city: 'Hyderabad',
          state: 'Telangana',
          locality: 'Secunderabad',
          latitude: 17.4338,
          longitude: 78.5044,
          category: 'Railway Station',
          isApproved: true,
        },
        {
          id: 'pub_hyd_hitec_metro',
          name: 'HITEC City Metro Station Hub',
          type: 'PUBLIC_POINT' as any,
          city: 'Hyderabad',
          state: 'Telangana',
          locality: 'Madhapur',
          latitude: 17.4474,
          longitude: 78.3762,
          category: 'Metro Station Hub',
          isApproved: true,
        },
        {
          id: 'pub_hyd_mgbs_bus',
          name: 'Mahatma Gandhi Bus Station (MGBS)',
          type: 'BUS_TERMINAL' as any,
          city: 'Hyderabad',
          state: 'Telangana',
          locality: 'Gowliguda',
          latitude: 17.3789,
          longitude: 78.4812,
          category: 'Bus Terminal',
          isApproved: true,
        },
        {
          id: 'pub_mum_csmia',
          name: 'Chhatrapati Shivaji Maharaj International Airport (BOM)',
          type: 'AIRPORT' as any,
          city: 'Mumbai',
          state: 'Maharashtra',
          locality: 'Andheri East',
          latitude: 19.0896,
          longitude: 72.8656,
          category: 'Airport Terminal',
          isApproved: true,
        },
        {
          id: 'pub_mum_bandra_term',
          name: 'Bandra Terminus Station',
          type: 'RAILWAY_STATION' as any,
          city: 'Mumbai',
          state: 'Maharashtra',
          locality: 'Bandra East',
          latitude: 19.0617,
          longitude: 72.8427,
          category: 'Railway Station',
          isApproved: true,
        },
        {
          id: 'pub_blr_kia',
          name: 'Kempegowda International Airport (BLR)',
          type: 'AIRPORT' as any,
          city: 'Bangalore',
          state: 'Karnataka',
          locality: 'Devanahalli',
          latitude: 13.1986,
          longitude: 77.7066,
          category: 'Airport Terminal',
          isApproved: true,
        },
      ];

      for (const p of seedPoints) {
        await this.prisma.publicTransportPoint.upsert({
          where: { id: p.id },
          update: {},
          create: p,
        });
      }

      items = await this.prisma.publicTransportPoint.findMany({
        where: {
          isApproved: true,
          ...(city ? { city: { equals: city, mode: 'insensitive' } } : {}),
        },
      });
    }

    return items;
  }

  async calculateDeliveryQuote(dto: CalculateDeliveryQuoteDto) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: dto.vendorId },
      include: { pickupHubs: { where: { isActive: true } } },
    });
    if (!vendor) {
      throw new NotFoundException('Vendor not found.');
    }

    const policy: any = await this.getVendorDeliveryPolicy(vendor.userId || vendor.id);

    const hubs = vendor.pickupHubs || [];
    let pickupHub: any = null;
    if (dto.pickupLocationId) {
      pickupHub = hubs.find((h: any) => h.id === dto.pickupLocationId);
    }
    if (!pickupHub && hubs.length > 0) {
      pickupHub = hubs[0];
    }

    let returnHub: any = null;
    if (dto.returnLocationId) {
      returnHub = hubs.find((h: any) => h.id === dto.returnLocationId);
    }
    if (!returnHub) {
      returnHub = pickupHub;
    }

    let originLat = pickupHub?.latitude || vendor.latitude || 17.4483;
    let originLng = pickupHub?.longitude || vendor.longitude || 78.3915;

    let distanceKm = 0;
    let deliveryFee = 0;
    let isDeliveryAvailable = true;
    let deliveryReason: string | undefined;

    if (dto.customerLatitude !== undefined && dto.customerLongitude !== undefined) {
      this.validateCoordinates(dto.customerLatitude, dto.customerLongitude);

      const rawDist = this.geoService
        ? this.geoService.calculateDistanceKm(originLat, originLng, dto.customerLatitude, dto.customerLongitude)
        : this.calculateHaversine(originLat, originLng, dto.customerLatitude, dto.customerLongitude);
      distanceKm = Math.round(rawDist * 10) / 10;

      if (!policy.deliveryEnabled) {
        isDeliveryAvailable = false;
        deliveryReason = 'Vendor does not currently offer customer address delivery.';
      } else if (distanceKm > policy.maxDeliveryRadiusKm) {
        isDeliveryAvailable = false;
        deliveryReason = `Customer address (${distanceKm} km) exceeds vendor's maximum delivery radius of ${policy.maxDeliveryRadiusKm} km.`;
      } else {
        if (policy.pricingModel === DeliveryPricingModelEnum.FREE) {
          deliveryFee = 0;
        } else if (policy.pricingModel === DeliveryPricingModelEnum.FIXED) {
          deliveryFee = policy.baseDeliveryFee || 300.0;
        } else if (policy.pricingModel === DeliveryPricingModelEnum.DISTANCE_BASED) {
          if (distanceKm <= (policy.freeDeliveryWithinKm || 0)) {
            deliveryFee = 0;
          } else {
            const extraKm = distanceKm - (policy.freeDeliveryWithinKm || 0);
            deliveryFee = (policy.baseDeliveryFee || 100.0) + extraKm * (policy.perKmDeliveryFee || 20.0);
          }
        }
      }
    }

    let oneWaySurcharge = 0;
    const isDifferentLocation = dto.pickupLocationId && dto.returnLocationId && dto.pickupLocationId !== dto.returnLocationId;
    if (isDifferentLocation) {
      const matrixItem = await this.prisma.vendorLocationMatrix.findUnique({
        where: {
          vendorId_pickupLocationId_returnLocationId: {
            vendorId: vendor.id,
            pickupLocationId: dto.pickupLocationId!,
            returnLocationId: dto.returnLocationId!,
          },
        },
      });

      if (matrixItem) {
        oneWaySurcharge = matrixItem.isSupported ? Number(matrixItem.oneWaySurcharge) : 0;
      } else if (returnHub?.oneWayFee) {
        oneWaySurcharge = Number(returnHub.oneWayFee);
      } else {
        oneWaySurcharge = 250.0;
      }
    }

    const pickupFee = pickupHub ? Number(pickupHub.pickupFee || 0) : 0;
    const returnFee = returnHub ? Number(returnHub.returnFee || 0) : 0;
    const totalFulfillmentFee = Math.round(deliveryFee + oneWaySurcharge + pickupFee + returnFee);

    return {
      isAvailable: isDeliveryAvailable,
      distanceKm,
      deliveryFee: Math.round(deliveryFee),
      pickupFee,
      returnFee,
      oneWaySurcharge: Math.round(oneWaySurcharge),
      totalFulfillmentFee,
      pricingModel: policy.pricingModel,
      maxDeliveryRadiusKm: policy.maxDeliveryRadiusKm,
      estimatedMinutes: distanceKm > 0 ? Math.round(distanceKm * 2.5) + 15 : 0,
      reason: deliveryReason,
    };
  }

  async adminGetLocations(query?: { city?: string; status?: string; type?: string }) {
    const cityFilter = query?.city && query.city !== 'All' ? { city: { equals: query.city, mode: 'insensitive' as const } } : {};

    const hubs = await this.prisma.pickupHub.findMany({
      where: {
        ...cityFilter,
      },
      include: {
        cars: { select: { id: true, make: true, model: true, registrationNumber: true } },
        vendor: { select: { id: true, businessName: true, ownerName: true, city: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    let results = hubs.map((h) => this.parseLocationMetadata(h));

    if (query?.status && query.status !== 'ALL') {
      results = results.filter((r) => r.status === query.status);
    }
    if (query?.type && query.type !== 'ALL') {
      results = results.filter((r) => r.type === query.type);
    }

    return results;
  }

  async adminGetLocationById(locationId: string) {
    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: locationId },
      include: {
        cars: { select: { id: true, make: true, model: true, registrationNumber: true } },
        exceptions: true,
        vendor: { select: { id: true, businessName: true, ownerName: true, city: true } },
      },
    });
    if (!hub) {
      throw new NotFoundException('Location not found.');
    }
    return this.parseLocationMetadata(hub);
  }

  async adminUpdateLocationStatus(
    adminUserId: string,
    locationId: string,
    status: VendorLocationStatusEnum,
  ) {
    const hub = await this.prisma.pickupHub.findUnique({
      where: { id: locationId },
      include: { cars: { select: { id: true } } },
    });
    if (!hub) {
      throw new NotFoundException('Location not found.');
    }

    let existingMeta: any = {};
    if (hub.operatingHours && hub.operatingHours.startsWith('{')) {
      try {
        existingMeta = JSON.parse(hub.operatingHours);
      } catch (e) {
        existingMeta = {};
      }
    }

    const previousStatus = existingMeta.status || (hub.isActive ? VendorLocationStatusEnum.ACTIVE : VendorLocationStatusEnum.INACTIVE);
    const updatedMeta = {
      ...existingMeta,
      status,
    };

    const updated = await this.prisma.pickupHub.update({
      where: { id: locationId },
      data: {
        isActive: status === VendorLocationStatusEnum.ACTIVE,
        operatingHours: JSON.stringify(updatedMeta),
      },
      include: { cars: { select: { id: true, make: true, model: true, registrationNumber: true } } },
    });

    if (this.cacheService) {
      await this.cacheService.invalidatePattern('cache:hubs:*');
      await this.cacheService.invalidatePattern('cache:search:cars:*');
    }

    if (this.auditLogService && adminUserId) {
      await this.auditLogService.log(
        adminUserId,
        'ADMIN_LOCATION_STATUS_UPDATE',
        'PickupHub',
        locationId,
        { oldStatus: previousStatus, newStatus: status },
      );
    }

    return this.parseLocationMetadata(updated);
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

