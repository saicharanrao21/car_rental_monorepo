import { Test, TestingModule } from '@nestjs/testing';
import { CarsService } from './cars.service';
import { PrismaService } from '../prisma/prisma.service';
import { VerificationStatus, BookingStatus, CarCategory } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';
import { CarsQueryDto, SortByOption } from './dto/cars-query.dto';

describe('Phase 10.4: Date-First Car Availability Search Tests', () => {
  let carsService: CarsService;
  let prisma: any;

  const sampleVendor = {
    id: 'vendor-1',
    businessName: 'Speedy Rentals',
    ownerName: 'Alice',
    city: 'Mumbai',
    locality: 'Andheri',
    rating: 4.8,
    latitude: 19.1136,
    longitude: 72.8697,
    verificationStatus: VerificationStatus.VERIFIED,
    isSponsored: false,
    boostExpiresAt: null,
  };

  const sampleCar1 = {
    id: 'car-1',
    vendorId: 'vendor-1',
    make: 'Hyundai',
    model: 'Creta',
    year: 2023,
    type: CarCategory.SUV,
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    pricePerKm: 15,
    pricePerDay: 2500,
    pricePerHour: 150,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
    blockedDates: [] as Date[],
    vendor: sampleVendor,
    mileagePackages: [],
  };

  const sampleCar2 = {
    id: 'car-2',
    vendorId: 'vendor-1',
    make: 'Maruti',
    model: 'Swift',
    year: 2022,
    type: CarCategory.HATCHBACK,
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    pricePerKm: 12,
    pricePerDay: 1800,
    pricePerHour: 100,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE'],
    blockedDates: [] as Date[],
    vendor: sampleVendor,
    mileagePackages: [],
  };

  beforeEach(async () => {
    prisma = {
      car: {
        findMany: jest.fn().mockImplementation((args: any) => {
          let cars = [sampleCar1, sampleCar2];
          if (args?.where?.id?.notIn) {
            cars = cars.filter((c) => !args.where.id.notIn.includes(c.id));
          }
          if (args?.where?.type) {
            cars = cars.filter((c) => c.type === args.where.type);
          }
          if (args?.where?.availableTripTypes?.has) {
            cars = cars.filter((c) =>
              c.availableTripTypes.includes(args.where.availableTripTypes.has),
            );
          }
          return Promise.resolve(cars);
        }),
        findUnique: jest.fn(),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      platformSettings: {
        findUnique: jest.fn().mockResolvedValue({
          enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
        }),
      },
      supportedCity: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CarsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    carsService = module.get<CarsService>(CarsService);
  });

  describe('Date Validation & Range Safety', () => {
    it('Scenario 1: Rejects search if only startDate is provided without endDate', async () => {
      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
      };
      await expect(carsService.searchCars(query, false)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('Scenario 2: Rejects search if only endDate is provided without startDate', async () => {
      const query: CarsQueryDto = {
        city: 'Mumbai',
        endDate: '2026-08-26T10:00:00.000Z',
      };
      await expect(carsService.searchCars(query, false)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('Scenario 3: Rejects search if startDate >= endDate', async () => {
      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-26T10:00:00.000Z',
        endDate: '2026-08-24T10:00:00.000Z',
      };
      await expect(carsService.searchCars(query, false)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('Scenario 4: Rejects search if date string is invalid', async () => {
      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: 'invalid-date',
        endDate: '2026-08-26T10:00:00.000Z',
      };
      await expect(carsService.searchCars(query, false)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('Active Booking Overlap Filtering', () => {
    it('Scenario 5: Returns all active cars when no bookings exist for the requested dates', async () => {
      prisma.booking.findMany.mockResolvedValue([]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(2);
      expect(result.data.map((c: any) => c.id)).toEqual(['car-1', 'car-2']);
      expect(prisma.booking.findMany).toHaveBeenCalledWith({
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
          startDate: { lt: new Date('2026-08-26T10:00:00.000Z') },
          endDate: { gt: new Date('2026-08-24T10:00:00.000Z') },
        },
        select: { carId: true },
        distinct: ['carId'],
      });
    });

    it('Scenario 6: Excludes car with overlapping CONFIRMED booking', async () => {
      prisma.booking.findMany.mockResolvedValue([{ carId: 'car-1' }]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-2');
    });

    it('Scenario 7: Excludes car with overlapping PENDING booking', async () => {
      prisma.booking.findMany.mockResolvedValue([{ carId: 'car-2' }]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-1');
    });

    it('Scenario 7b: Cancelled booking does not incorrectly block availability', async () => {
      // Prisma query only filters active booking statuses; CANCELLED bookings are not returned in findMany
      prisma.booking.findMany.mockImplementation((args: any) => {
        const statuses = args.where.status.in;
        expect(statuses).not.toContain(BookingStatus.CANCELLED);
        expect(statuses).not.toContain(BookingStatus.COMPLETED);
        expect(statuses).not.toContain(BookingStatus.REJECTED);
        expect(statuses).not.toContain(BookingStatus.REFUNDED);
        return Promise.resolve([]);
      });

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(2);
      expect(result.data.map((c: any) => c.id)).toContain('car-1');
      expect(result.data.map((c: any) => c.id)).toContain('car-2');
    });
  });

  describe('Boundary Condition Semantics', () => {
    it('Scenario 8: Overlap query matches half-open interval semantics ([start, end))', async () => {
      const requestedStart = new Date('2026-08-25T10:00:00.000Z');
      const requestedEnd = new Date('2026-08-28T10:00:00.000Z');

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: requestedStart.toISOString(),
        endDate: requestedEnd.toISOString(),
      };

      await carsService.searchCars(query, false);

      expect(prisma.booking.findMany).toHaveBeenCalledWith({
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
          startDate: { lt: requestedEnd },
          endDate: { gt: requestedStart },
        },
        select: { carId: true },
        distinct: ['carId'],
      });
    });
  });

  describe('Blocked Date Handling', () => {
    it('Scenario 9: Excludes car with blocked date inside the requested interval', async () => {
      const blockedCar = {
        ...sampleCar1,
        id: 'car-blocked',
        blockedDates: [new Date('2026-08-25T00:00:00.000Z')],
      };
      prisma.car.findMany.mockResolvedValue([blockedCar, sampleCar2]);
      prisma.booking.findMany.mockResolvedValue([]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-2');
    });

    it('Scenario 10: Retains car if blocked date is outside the requested interval', async () => {
      const unblockedCar = {
        ...sampleCar1,
        id: 'car-unblocked',
        blockedDates: [new Date('2026-08-30T00:00:00.000Z')],
      };
      prisma.car.findMany.mockResolvedValue([unblockedCar, sampleCar2]);
      prisma.booking.findMany.mockResolvedValue([]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(2);
      expect(result.data.map((c: any) => c.id)).toContain('car-unblocked');
      expect(result.data.map((c: any) => c.id)).toContain('car-2');
    });
  });

  describe('Legacy Search & Existing Filters Compatibility', () => {
    it('Scenario 11: Search without dates preserves legacy behavior and returns all available cars', async () => {
      const query: CarsQueryDto = {
        city: 'Mumbai',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(2);
      expect(prisma.booking.findMany).not.toHaveBeenCalled();
    });

    it('Scenario 12: Trip type filter is applied correctly alongside date search', async () => {
      prisma.booking.findMany.mockResolvedValue([]);

      const query: CarsQueryDto = {
        city: 'Mumbai',
        tripType: 'OUTSTATION',
        startDate: '2026-08-24T10:00:00.000Z',
        endDate: '2026-08-26T10:00:00.000Z',
      };

      const result = await carsService.searchCars(query, false);
      expect(result.data.length).toBe(1);
      expect(result.data[0].id).toBe('car-1');
    });
  });
});
