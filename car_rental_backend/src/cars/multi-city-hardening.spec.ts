import { Test, TestingModule } from '@nestjs/testing';
import { CarsService } from './cars.service';
import { PrismaService } from '../prisma/prisma.service';
import { Role, VerificationStatus } from '@prisma/client';

describe('MultiCityHardeningSpec', () => {
  let service: CarsService;
  let prisma: PrismaService;

  const mockSettings = {
    id: 'singleton',
    platformName: 'DriveGo',
    gstNumber: '27AAAAA1111A1Z1',
    supportEmail: 'support@drivego.in',
    supportPhone: '+919876543210',
    appVersion: '1.0.0',
    enabledTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
  };

  const mockMumbaiCity = {
    id: 'city-mumbai',
    name: 'Mumbai',
    state: 'Maharashtra',
    latitude: 19.076,
    longitude: 72.8777,
    isActive: true,
    enabledTripTypes: [], // Should fall back to global enabledTripTypes (SELF_DRIVE, OUTSTATION)
  };

  const mockDelhiCity = {
    id: 'city-delhi',
    name: 'Delhi',
    state: 'Delhi',
    latitude: 28.6139,
    longitude: 77.209,
    isActive: true,
    enabledTripTypes: ['SELF_DRIVE'], // City-specific override: Only SELF_DRIVE is enabled in Delhi
  };

  const mockMumbaiVendor = {
    id: 'vendor-mumbai',
    city: 'Mumbai',
    verificationStatus: VerificationStatus.VERIFIED,
    businessName: 'Mumbai Rentals',
    ownerName: 'Vendor A',
    locality: 'Bandra',
    rating: 4.8,
    latitude: 19.076,
    longitude: 72.8777,
    isSponsored: false,
    boostExpiresAt: null,
  };

  const mockDelhiVendor = {
    id: 'vendor-delhi',
    city: 'Delhi',
    verificationStatus: VerificationStatus.VERIFIED,
    businessName: 'Delhi Rentals',
    ownerName: 'Vendor B',
    locality: 'Connaught Place',
    rating: 4.5,
    latitude: 28.6139,
    longitude: 77.209,
    isSponsored: false,
    boostExpiresAt: null,
  };

  const mockMumbaiCar = {
    id: 'car-mumbai-swift',
    vendorId: 'vendor-mumbai',
    make: 'Maruti Suzuki',
    model: 'Swift',
    year: 2022,
    type: 'HATCHBACK',
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    pricePerDay: 1700,
    pricePerKm: 14,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
    vendor: mockMumbaiVendor,
  };

  const mockDelhiCar = {
    id: 'car-delhi-i20',
    vendorId: 'vendor-delhi',
    make: 'Hyundai',
    model: 'i20',
    year: 2023,
    type: 'HATCHBACK',
    fuelType: 'PETROL',
    seating: 5,
    isAC: true,
    pricePerDay: 1800,
    pricePerKm: 15,
    isAvailable: true,
    availableTripTypes: ['SELF_DRIVE', 'OUTSTATION'],
    vendor: mockDelhiVendor,
  };

  const mockPrismaService = {
    platformSettings: {
      findUnique: jest.fn().mockResolvedValue(mockSettings),
      create: jest.fn().mockResolvedValue(mockSettings),
    },
    supportedCity: {
      findFirst: jest.fn().mockImplementation(({ where }) => {
        const queryName = where.name?.equals?.toLowerCase();
        if (queryName === 'mumbai') return Promise.resolve(mockMumbaiCity);
        if (queryName === 'delhi') return Promise.resolve(mockDelhiCity);
        return Promise.resolve(null);
      }),
    },
    car: {
      findMany: jest.fn().mockImplementation(({ where }) => {
        let results = [mockMumbaiCar, mockDelhiCar];
        if (where.vendor?.city?.equals) {
          const targetCity = where.vendor.city.equals.toLowerCase();
          results = results.filter(
            (c) => c.vendor.city.toLowerCase() === targetCity,
          );
        }
        if (where.availableTripTypes?.has) {
          const trip = where.availableTripTypes.has;
          results = results.filter((c) => c.availableTripTypes.includes(trip));
        }
        return Promise.resolve(results);
      }),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CarsService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<CarsService>(CarsService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('1. City Isolation: City A (Mumbai) query does NOT return City B (Delhi) inventory', async () => {
    const res = await service.searchCars({ city: 'Mumbai' } as any, false);
    expect(res.data.length).toBe(1);
    expect(res.data[0].id).toBe('car-mumbai-swift');
    expect(res.data[0].vendor.city).toBe('Mumbai');
  });

  it('2. Active Trip Types: Searching SELF_DRIVE in Mumbai returns available cars', async () => {
    const res = await service.searchCars(
      { city: 'Mumbai', tripType: 'SELF_DRIVE' } as any,
      false,
    );
    expect(res.data.length).toBe(1);
    expect(res.data[0].id).toBe('car-mumbai-swift');
  });

  it('3. Disabled Trip Types: Searching LOCAL or AIRPORT_TRANSFER returns 0 cars globally', async () => {
    const resLocal = await service.searchCars(
      { city: 'Mumbai', tripType: 'LOCAL' } as any,
      false,
    );
    expect(resLocal.data.length).toBe(0);

    const resAirport = await service.searchCars(
      { city: 'Mumbai', tripType: 'AIRPORT_TRANSFER' } as any,
      false,
    );
    expect(resAirport.data.length).toBe(0);
  });

  it('4. City-specific Trip Type Override: Delhi has override enabledTripTypes = ["SELF_DRIVE"], so OUTSTATION returns 0 cars', async () => {
    const resOutstation = await service.searchCars(
      { city: 'Delhi', tripType: 'OUTSTATION' } as any,
      false,
    );
    expect(resOutstation.data.length).toBe(0);

    const resSelfDrive = await service.searchCars(
      { city: 'Delhi', tripType: 'SELF_DRIVE' } as any,
      false,
    );
    expect(resSelfDrive.data.length).toBe(1);
    expect(resSelfDrive.data[0].id).toBe('car-delhi-i20');
  });

  it('5. Fallback to Global Configuration: Mumbai has enabledTripTypes = [], so it falls back to PlatformSettings (SELF_DRIVE & OUTSTATION)', async () => {
    const resOutstation = await service.searchCars(
      { city: 'Mumbai', tripType: 'OUTSTATION' } as any,
      false,
    );
    expect(resOutstation.data.length).toBe(1);
    expect(resOutstation.data[0].id).toBe('car-mumbai-swift');
  });
});
