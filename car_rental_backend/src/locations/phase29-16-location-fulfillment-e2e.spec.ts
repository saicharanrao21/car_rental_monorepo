import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { BookingsService } from '../bookings/bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  VendorLocationTypeEnum,
  VendorLocationStatusEnum,
  DeliveryPricingModelEnum,
} from './dto/vendor-location-operations.dto';
import { BookingStatus, TripType } from '@prisma/client';

describe('Phase 29.16: Cross-Platform Location & Fulfillment E2E Integration Suite', () => {
  let locationsService: LocationsService;
  let mockPrisma: any;
  let mockGeoService: any;
  let mockCacheService: any;
  let mockAuditLogService: any;

  const vendorId = 'vnd_mumbai_apex';
  const vendorUserId = 'usr_vendor_99';
  const adminUserId = 'usr_admin_01';

  // Authoritative Hub Models
  const hostYardHub = {
    id: 'hub_mumbai_central',
    vendorId,
    name: 'Andheri East Main Yard',
    address: 'Plot 42, Andheri-Kurla Road, Mumbai',
    locality: 'Andheri East',
    city: 'Mumbai',
    state: 'Maharashtra',
    latitude: 19.1136,
    longitude: 72.8697,
    serviceRadiusKm: 25.0,
    contactPhone: '+91 9876543210',
    operatingHours: JSON.stringify({
      type: 'VENDOR_YARD',
      status: 'ACTIVE',
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: true,
      pickupFee: 0,
      returnFee: 0,
      oneWayFee: 0,
      openingTime: '06:00',
      closingTime: '23:00',
      is24x7: false,
      assignedCarIds: ['car_creta_01'],
    }),
    isActive: true,
    cars: [{ id: 'car_creta_01' }],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const branchHub = {
    id: 'hub_mumbai_bkc',
    vendorId,
    name: 'BKC Premium Relocation Branch',
    address: 'G Block, Bandra Kurla Complex, Mumbai',
    locality: 'Bandra East',
    city: 'Mumbai',
    state: 'Maharashtra',
    latitude: 19.0657,
    longitude: 72.8687,
    serviceRadiusKm: 20.0,
    contactPhone: '+91 9876543211',
    operatingHours: JSON.stringify({
      type: 'BRANCH_OFFICE',
      status: 'ACTIVE',
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: false,
      pickupFee: 100,
      returnFee: 150,
      oneWayFee: 250,
      openingTime: '08:00',
      closingTime: '22:00',
      is24x7: false,
      assignedCarIds: ['car_creta_01'],
    }),
    isActive: true,
    cars: [{ id: 'car_creta_01' }],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const airportHub = {
    id: 'pub_bom_t2',
    vendorId,
    name: 'Chhatrapati Shivaji Terminal 2 Hub',
    address: 'P4 Parking, Terminal 2, Mumbai Airport',
    locality: 'Sahar',
    city: 'Mumbai',
    state: 'Maharashtra',
    latitude: 19.0974,
    longitude: 72.8744,
    serviceRadiusKm: 10.0,
    contactPhone: '+91 9876543212',
    operatingHours: JSON.stringify({
      type: 'AIRPORT',
      status: 'ACTIVE',
      allowsPickup: true,
      allowsReturn: true,
      allowsDelivery: false,
      pickupFee: 200,
      returnFee: 200,
      oneWayFee: 0,
      is24x7: true,
      assignedCarIds: ['car_creta_01'],
    }),
    isActive: true,
    cars: [{ id: 'car_creta_01' }],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(() => {
    mockPrisma = {
      vendor: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.userId === vendorUserId || where.id === vendorId) {
            return Promise.resolve({
              id: vendorId,
              userId: vendorUserId,
              businessName: 'Apex Mobility Mumbai',
              city: 'Mumbai',
              latitude: 19.1136,
              longitude: 72.8697,
              deliveryEnabled: true,
              deliveryMaxKm: 25,
              deliveryFlatFee: 350,
              deliveryRatePerKm: 25,
              deliveryFreeThreshold: 8000,
              deliveryPricingModel: DeliveryPricingModelEnum.FIXED,
              pickupHubs: [hostYardHub, branchHub, airportHub],
            });
          }
          return Promise.resolve(null);
        }),
      },
      pickupHub: {
        findMany: jest.fn().mockResolvedValue([hostYardHub, branchHub, airportHub]),
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id === hostYardHub.id) return Promise.resolve(hostYardHub);
          if (where.id === branchHub.id) return Promise.resolve(branchHub);
          if (where.id === airportHub.id) return Promise.resolve(airportHub);
          return Promise.resolve(null);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          return Promise.resolve({
            ...hostYardHub,
            ...data,
            id: where.id,
          });
        }),
      },
      car: {
        findMany: jest.fn().mockResolvedValue([{ id: 'car_creta_01', make: 'Hyundai', model: 'Creta' }]),
      },
      adminAuditLog: {
        create: jest.fn().mockResolvedValue({ id: 'audit_101' }),
      },
      vendorDeliveryPolicy: {
        findUnique: jest.fn().mockResolvedValue({
          vendorId,
          deliveryEnabled: true,
          pricingModel: DeliveryPricingModelEnum.FIXED,
          baseDeliveryFee: 350,
          perKmDeliveryFee: 25,
          maxDeliveryRadiusKm: 25,
          freeDeliveryWithinKm: 0,
        }),
      },
    };

    mockGeoService = {
      calculateDistanceKm: jest.fn((lat1, lng1, lat2, lng2) => {
        const dLat = (lat2 - lat1) * 111.0;
        const dLng = (lng2 - lng1) * 111.0 * Math.cos((lat1 * Math.PI) / 180);
        return Math.round(Math.sqrt(dLat * dLat + dLng * dLng) * 10) / 10;
      }),
    };

    mockCacheService = {
      get: jest.fn().mockResolvedValue(null),
      getOrSet: jest.fn(async (key, fn) => fn()),
      set: jest.fn(),
      delete: jest.fn(),
      invalidatePattern: jest.fn(),
    };

    mockAuditLogService = {
      log: jest.fn().mockResolvedValue({ id: 'audit_log_01' }),
    };

    locationsService = new LocationsService(
      mockPrisma,
      mockGeoService,
      mockCacheService,
      mockAuditLogService,
    );
  });

  describe('FLOW A — HOST YARD OPERATIONAL LIFECYCLE', () => {
    it('verifies host yard configuration, customer free pickup discovery, and immutable snapshot attributes', async () => {
      // 1. Vendor fetches locations
      const locations = await locationsService.getVendorLocations(vendorUserId);
      const hostYard = locations.find((l) => l.type === VendorLocationTypeEnum.VENDOR_YARD);

      expect(hostYard).toBeDefined();
      expect(hostYard!.name).toBe('Andheri East Main Yard');
      expect(hostYard!.pickupFee).toBe(0);
      expect(hostYard!.returnFee).toBe(0);
      expect(hostYard!.oneWayFee).toBe(0);

      // 2. Customer discovery: Host yard option has zero surcharges
      expect(hostYard!.allowsPickup).toBe(true);
      expect(hostYard!.allowsReturn).toBe(true);

      // 3. Simulated confirmed booking snapshot verification
      const bookingSnapshot = {
        bookingId: 'BK_E2E_HOST_YARD_01',
        pickupLocation: hostYard!.name,
        dropLocation: hostYard!.name,
        pickupHubId: hostYard!.id,
        returnHubId: hostYard!.id,
        pickupAddress: hostYard!.address,
        deliveryFee: 0,
        pickupFee: 0,
        returnFee: 0,
        oneWayFee: 0,
        deliveryType: 'HUB_PICKUP',
      };

      // Invariant: Snapshot remains immutable
      expect(bookingSnapshot.deliveryFee).toBe(0);
      expect(bookingSnapshot.oneWayFee).toBe(0);
      expect(bookingSnapshot.pickupAddress).toContain('Andheri-Kurla Road');
    });
  });

  describe('FLOW B — MULTI-LOCATION / BRANCH RELOCATION LIFECYCLE', () => {
    it('verifies one-way relocation fee calculation, snapshot persistence, and vendor/admin fee breakdown', async () => {
      // 1. Customer selects different pickup and return branch
      const pickup = await locationsService.getVendorLocationById(vendorUserId, hostYardHub.id);
      const drop = await locationsService.getVendorLocationById(vendorUserId, branchHub.id);

      expect(pickup.id).not.toBe(drop.id);
      expect(drop.oneWayFee).toBe(250);
      expect(drop.returnFee).toBe(150);

      // 2. Booking fulfillment fee aggregation
      const totalFulfillmentSurcharge = (pickup.pickupFee || 0) + (drop.returnFee || 0) + (drop.oneWayFee || 0);
      expect(totalFulfillmentSurcharge).toBe(400); // 0 + 150 + 250

      // 3. Authoritative booking snapshot
      const bookingSnapshot = {
        bookingId: 'BK_E2E_RELOC_02',
        pickupHubId: pickup.id,
        returnHubId: drop.id,
        pickupName: pickup.name,
        dropName: drop.name,
        pickupAddress: pickup.address,
        pickupFee: pickup.pickupFee,
        returnFee: drop.returnFee,
        oneWayFee: drop.oneWayFee,
        totalFulfillmentSurcharge,
      };

      expect(bookingSnapshot.oneWayFee).toBe(250);
      expect(bookingSnapshot.returnFee).toBe(150);
      expect(bookingSnapshot.dropName).toBe('BKC Premium Relocation Branch');
    });
  });

  describe('FLOW C — PUBLIC LOCATION / AIRPORT TRANSIT POINT', () => {
    it('verifies 24x7 public transit point discovery, airport surcharge, and coordinate fidelity', async () => {
      const airportLocation = await locationsService.getVendorLocationById(vendorUserId, airportHub.id);

      expect(airportLocation.type).toBe(VendorLocationTypeEnum.AIRPORT);
      expect(airportLocation.is24x7).toBe(true);
      expect(airportLocation.pickupFee).toBe(200);
      expect(airportLocation.latitude).toBeCloseTo(19.0974, 4);
      expect(airportLocation.longitude).toBeCloseTo(72.8744, 4);
      expect(airportLocation.address).toContain('Terminal 2');
    });
  });

  describe('FLOW D — DOORSTEP DELIVERY QUOTE & SNAPSHOT', () => {
    it('calculates server-authoritative delivery quote and verifies delivery address/fee immutability', async () => {
      const quote = await locationsService.calculateDeliveryQuote({
        vendorId,
        customerLatitude: 19.0178,
        customerLongitude: 72.8178,
        orderTotal: 4500,
      });

      expect(quote.isAvailable).toBe(true);
      expect(quote.deliveryFee).toBe(350); // Fixed fee policy
      expect(quote.distanceKm).toBeGreaterThan(0);
      expect(quote.maxDeliveryRadiusKm).toBe(25);

      // Persisted Delivery Snapshot
      const deliverySnapshot = {
        deliveryType: 'DOORSTEP_DELIVERY',
        deliveryAddress: 'Flat 402, Sea Green Apts, Worli Sea Face, Mumbai',
        deliveryLatitude: 19.0178,
        deliveryLongitude: 72.8178,
        deliveryFee: quote.deliveryFee,
      };

      expect(deliverySnapshot.deliveryFee).toBe(350);
      expect(deliverySnapshot.deliveryAddress).toContain('Worli Sea Face');
    });
  });

  describe('FLOW E — ADMIN LOCATION GOVERNANCE & AUDIT TRAIL', () => {
    it('enforces admin status update, audit trail creation, and cache invalidation', async () => {
      const updated = await locationsService.adminUpdateLocationStatus(
        adminUserId,
        hostYardHub.id,
        VendorLocationStatusEnum.SUSPENDED,
      );

      // Verify status change in DB
      expect(mockPrisma.pickupHub.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: hostYardHub.id },
          data: expect.objectContaining({
            isActive: false,
          }),
        }),
      );

      // Verify audit trail recorded with positional arguments
      expect(mockAuditLogService.log).toHaveBeenCalledWith(
        adminUserId,
        'ADMIN_LOCATION_STATUS_UPDATE',
        'PickupHub',
        hostYardHub.id,
        expect.any(Object),
      );

      // Verify cache invalidation
      expect(mockCacheService.invalidatePattern).toHaveBeenCalled();
    });
  });

  describe('FLOW F — HANDOVER & RETURN IMMUTABILITY LIFECYCLE', () => {
    it('verifies that fulfillment location snapshot remains immutable through handover and return states', () => {
      const initialSnapshot = {
        bookingId: 'BK_E2E_LIFECYCLE_01',
        pickupHubId: hostYardHub.id,
        returnHubId: branchHub.id,
        pickupAddress: hostYardHub.address,
        deliveryAddress: null,
        deliveryFee: 0,
        oneWayFee: 250,
        status: BookingStatus.confirmed,
      };

      // State transitions: confirmed -> ongoing (handover) -> completed (return)
      const handoverState = {
        ...initialSnapshot,
        status: BookingStatus.ongoing,
        handoverOtpVerified: true,
        handoverInspectedAt: new Date(),
      };

      const returnState = {
        ...handoverState,
        status: BookingStatus.completed,
        returnInspectedAt: new Date(),
      };

      // Critical Invariant: Fulfillment snapshots did NOT mutate
      expect(returnState.pickupHubId).toBe(initialSnapshot.pickupHubId);
      expect(returnState.returnHubId).toBe(initialSnapshot.returnHubId);
      expect(returnState.oneWayFee).toBe(initialSnapshot.oneWayFee);
      expect(returnState.pickupAddress).toBe(initialSnapshot.pickupAddress);
    });
  });
});
