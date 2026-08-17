import { Test, TestingModule } from '@nestjs/testing';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { BookingStatus, EmergencyStatus, IncidentType } from '@prisma/client';

describe('Feature 35 — Locations & Live Maps Spec', () => {
  let service: LocationsService;
  let controller: LocationsController;
  let prisma: PrismaService;

  const mockPrismaService = {
    supportedCity: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    vendor: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    booking: {
      findMany: jest.fn(),
    },
    emergencyRequest: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [LocationsController],
      providers: [
        LocationsService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<LocationsService>(LocationsService);
    controller = module.get<LocationsController>(LocationsController);
    prisma = module.get<PrismaService>(PrismaService);

    jest.clearAllMocks();
  });

  describe('1. Haversine Distance & Route Estimation', () => {
    it('should compute exact great-circle distance between Mumbai and Pune (~120 km)', () => {
      const mumbai = { lat: 19.076, lng: 72.8777 };
      const pune = { lat: 18.5204, lng: 73.8567 };

      const distance = service.calculateHaversine(
        mumbai.lat,
        mumbai.lng,
        pune.lat,
        pune.lng,
      );

      // Distance should be approximately 119.8 km
      expect(distance).toBeGreaterThan(115);
      expect(distance).toBeLessThan(125);
    });

    it('should estimate driving route distance with road curvature factor (1.25x) and ETA', () => {
      const origin = { lat: 17.385, lng: 78.4867 }; // Hyderabad
      const dest = { lat: 17.45, lng: 78.38 }; // Hitec City (~13km direct)

      const result = service.estimateRoute(
        origin.lat,
        origin.lng,
        dest.lat,
        dest.lng,
      );

      expect(result.distanceKm).toBeGreaterThan(10);
      expect(result.estimatedMinutes).toBeGreaterThanOrEqual(5);
      expect(result.formattedDistance).toContain('km');
      expect(result.formattedDuration).toBeDefined();
    });

    it('should throw BadRequestException when coordinates are outside valid lat/lng boundaries', () => {
      expect(() =>
        service.estimateRoute(95.0, 78.0, 17.0, 78.0),
      ).toThrow(BadRequestException);

      expect(() =>
        service.estimateRoute(17.0, -195.0, 17.0, 78.0),
      ).toThrow(BadRequestException);

      expect(() =>
        service.estimateRoute(NaN, 78.0, 17.0, 78.0),
      ).toThrow(BadRequestException);
    });
  });

  describe('2. Geocoding & Reverse Geocoding', () => {
    it('should forward geocode a known city to its registered coordinates', async () => {
      mockPrismaService.supportedCity.findFirst.mockResolvedValue({
        name: 'Bangalore',
        state: 'Karnataka',
        latitude: 12.9716,
        longitude: 77.5946,
      });

      const result = await service.forwardGeocode('Bangalore');

      expect(result.city).toBe('Bangalore');
      expect(result.latitude).toBe(12.9716);
      expect(result.longitude).toBe(77.5946);
      expect(result.formattedAddress).toContain('Bangalore');
    });

    it('should reverse geocode coordinates and identify the nearest supported city', async () => {
      mockPrismaService.supportedCity.findMany.mockResolvedValue([
        { name: 'Hyderabad', state: 'Telangana', latitude: 17.385, longitude: 78.4867 },
        { name: 'Mumbai', state: 'Maharashtra', latitude: 19.076, longitude: 72.8777 },
      ]);

      const result = await service.reverseGeocode(17.44, 78.348); // Gachibowli near Hyd

      expect(result.city).toBe('Hyderabad');
      expect(result.state).toBe('Telangana');
      expect(result.latitude).toBe(17.44);
    });

    it('should throw BadRequestException for empty address query in forward geocode', async () => {
      await expect(service.forwardGeocode('')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('3. Doorstep Delivery Distance Verification', () => {
    it('should verify doorstep delivery is within allowed 50km radius', async () => {
      mockPrismaService.vendor.findUnique.mockResolvedValue({
        id: 'vnd_hyd_1',
        businessName: 'Hyd Premium Cars',
        city: 'Hyderabad',
        latitude: 17.385,
        longitude: 78.4867,
      });

      const destLat = 17.44;
      const destLng = 78.38; // ~15km away

      const result = await service.verifyDeliveryDistance(
        'vnd_hyd_1',
        destLat,
        destLng,
      );

      expect(result.isEligible).toBe(true);
      expect(result.distanceKm).toBeLessThanOrEqual(50);
      expect(result.vendorName).toBe('Hyd Premium Cars');
    });

    it('should reject doorstep delivery when distance exceeds 50km limit', async () => {
      mockPrismaService.vendor.findUnique.mockResolvedValue({
        id: 'vnd_hyd_1',
        businessName: 'Hyd Premium Cars',
        city: 'Hyderabad',
        latitude: 17.385,
        longitude: 78.4867,
      });

      const distantLat = 18.5;
      const distantLng = 79.5; // ~150km away

      const result = await service.verifyDeliveryDistance(
        'vnd_hyd_1',
        distantLat,
        distantLng,
      );

      expect(result.isEligible).toBe(false);
      expect(result.distanceKm).toBeGreaterThan(50);
    });

    it('should throw NotFoundException when vendor ID does not exist', async () => {
      mockPrismaService.vendor.findUnique.mockResolvedValue(null);

      await expect(
        service.verifyDeliveryDistance('vnd_missing', 17.0, 78.0),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('4. Operational Locations Overview for Admin', () => {
    it('should aggregate cities, active vendors, ongoing trips, and active emergency alerts', async () => {
      mockPrismaService.supportedCity.findMany.mockResolvedValue([
        { id: 'city_1', name: 'Hyderabad', state: 'Telangana', latitude: 17.385, longitude: 78.4867 },
      ]);
      mockPrismaService.vendor.findMany.mockResolvedValue([
        { id: 'vnd_1', businessName: 'Speedy Fleet', city: 'Hyderabad', latitude: 17.4, longitude: 78.4 },
      ]);
      mockPrismaService.booking.findMany.mockResolvedValue([
        {
          id: 'bkg_ongoing_1',
          tripType: 'SELF_DRIVE',
          pickupLocation: 'Airport Hub',
          status: BookingStatus.ONGOING,
          pickupLatitude: 17.24,
          pickupLongitude: 78.42,
          customer: { name: 'Sai Charan', phone: '+919876543210' },
          car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'TS09EA1234' },
        },
      ]);
      mockPrismaService.emergencyRequest.findMany.mockResolvedValue([
        {
          id: 'sos_1',
          incidentType: IncidentType.FLAT_TYRE,
          status: EmergencyStatus.REQUESTED,
          latitude: 17.35,
          longitude: 78.45,
          locationAddress: 'PVNR Expressway, Pillar 120',
          customer: { name: 'Priya Reddy', phone: '+919876543211' },
        },
      ]);

      const overview = await service.getOperationalLocationsOverview('Hyderabad');

      expect(overview.totalHubs).toBe(1);
      expect(overview.totalActiveGarages).toBe(1);
      expect(overview.totalOnTripVehicles).toBe(1);
      expect(overview.totalActiveSosAlerts).toBe(1);
      expect(overview.activeBookings[0].car.registrationNumber).toBe('TS09EA1234');
    });
  });

  describe('5. Locations Controller Routes', () => {
    it('controller calculateDistance should return route estimate', async () => {
      const res = await controller.calculateDistance({
        originLat: '17.3850',
        originLng: '78.4867',
        destLat: '17.4500',
        destLng: '78.3800',
      });

      expect(res.distanceKm).toBeGreaterThan(0);
      expect(res.estimatedMinutes).toBeGreaterThanOrEqual(5);
    });

    it('controller reverseGeocode should return address data', async () => {
      mockPrismaService.supportedCity.findMany.mockResolvedValue([
        { name: 'Hyderabad', state: 'Telangana', latitude: 17.385, longitude: 78.4867 },
      ]);

      const res = await controller.reverseGeocode({
        lat: '17.3850',
        lng: '78.4867',
      });

      expect(res.city).toBe('Hyderabad');
    });

    it('controller getAdminOverview should return aggregated overview', async () => {
      mockPrismaService.supportedCity.findMany.mockResolvedValue([]);
      mockPrismaService.vendor.findMany.mockResolvedValue([]);
      mockPrismaService.booking.findMany.mockResolvedValue([]);
      mockPrismaService.emergencyRequest.findMany.mockResolvedValue([]);

      const res = await controller.getAdminOverview('All');
      expect(res.totalHubs).toBe(0);
    });
  });
});
