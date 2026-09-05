import { Test, TestingModule } from '@nestjs/testing';
import { VehicleAvailabilityService } from './vehicle-availability.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingLockService } from '../redis/booking-lock.service';
import { NotificationRealtimeService } from '../notifications/notification-realtime.service';
import {
  BookingStatus,
  Role,
  VerificationStatus,
  VehicleBlockType,
  VehicleHoldStatus,
} from '@prisma/client';
import {
  BadRequestException,
  ForbiddenException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';

describe('Phase 34 — Canonical Vehicle Availability & Inventory Integrity', () => {
  let availabilityService: VehicleAvailabilityService;
  let prismaMock: any;
  let lockServiceMock: any;
  let realtimeMock: any;

  const mockCar = {
    id: 'car-p34-001',
    name: 'Hyundai Creta SX',
    type: 'SUV',
    vendorId: 'vendor-p34-101',
    pickupHubId: 'hub-p34-blr-01',
    isAvailable: true,
    blockedDates: [],
    vendor: {
      id: 'vendor-p34-101',
      userId: 'user-vendor-101',
      city: 'Bangalore',
      verificationStatus: VerificationStatus.VERIFIED,
    },
    pickupHub: {
      id: 'hub-p34-blr-01',
      name: 'Indiranagar Hub',
      city: 'Bangalore',
    },
  };

  beforeEach(async () => {
    prismaMock = {
      car: {
        findUnique: jest.fn().mockResolvedValue(mockCar),
        findMany: jest.fn(),
      },
      booking: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      vehicleBlock: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        create: jest.fn(),
        delete: jest.fn().mockResolvedValue({ id: 'block-001' }),
      },
      vehicleHold: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      locationException: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      vendor: {
        findUnique: jest.fn().mockResolvedValue({ userId: 'user-vendor-101' }),
      },
      $transaction: jest.fn((cb) => cb(prismaMock)),
    };

    lockServiceMock = {
      acquireLock: jest.fn().mockResolvedValue('test-lock-token'),
      releaseLock: jest.fn().mockResolvedValue(true),
    };

    realtimeMock = {
      emitToUser: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehicleAvailabilityService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: BookingLockService, useValue: lockServiceMock },
        { provide: NotificationRealtimeService, useValue: realtimeMock },
      ],
    }).compile();

    availabilityService = module.get<VehicleAvailabilityService>(VehicleAvailabilityService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // 1. Vehicle available
  it('1. should return available: true when no conflicting bookings, blocks, or holds exist', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(true);
    expect(result.conflicts).toHaveLength(0);
  });

  // 2. Vehicle unavailable
  it('2. should return available: false when car is deactivated or marked unavailable', async () => {
    prismaMock.car.findUnique.mockResolvedValueOnce({
      ...mockCar,
      isAvailable: false,
    });

    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(false);
    expect(result.reason).toContain('marked as unavailable or deactivated');
    expect(result.conflicts[0].type).toBe('BLOCK');
  });

  // 3. Exact interval conflict
  it('3. should detect exact interval conflict and return available: false', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([
      {
        id: 'booking-exact-001',
        startDate: start,
        endDate: end,
        status: BookingStatus.CONFIRMED,
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(false);
    expect(result.conflicts).toHaveLength(1);
    expect(result.conflicts[0].type).toBe('BOOKING');
    expect(result.conflicts[0].id).toBe('booking-exact-001');
  });

  // 4. Partial interval conflict
  it('4. should detect partial interval overlap (start before, end during)', async () => {
    const requestedStart = new Date('2026-10-03T10:00:00Z');
    const requestedEnd = new Date('2026-10-08T10:00:00Z');

    const existingStart = new Date('2026-10-01T10:00:00Z');
    const existingEnd = new Date('2026-10-04T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([
      {
        id: 'booking-overlap-002',
        startDate: existingStart,
        endDate: existingEnd,
        status: BookingStatus.PENDING,
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, requestedStart, requestedEnd);

    expect(result.available).toBe(false);
    expect(result.conflicts[0].id).toBe('booking-overlap-002');
  });

  // 5. Contained interval conflict
  it('5. should detect contained interval overlap (existing booking inside requested interval)', async () => {
    const requestedStart = new Date('2026-10-01T10:00:00Z');
    const requestedEnd = new Date('2026-10-10T10:00:00Z');

    const existingStart = new Date('2026-10-03T10:00:00Z');
    const existingEnd = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([
      {
        id: 'booking-contained-003',
        startDate: existingStart,
        endDate: existingEnd,
        status: BookingStatus.CONFIRMED,
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, requestedStart, requestedEnd);

    expect(result.available).toBe(false);
    expect(result.conflicts[0].id).toBe('booking-contained-003');
  });

  // 6. Adjacent interval allowed
  it('6. should allow strictly adjacent intervals (E1 == S2) without conflict', () => {
    const b1Start = new Date('2026-10-01T10:00:00Z');
    const b1End = new Date('2026-10-05T10:00:00Z');

    const b2Start = new Date('2026-10-05T10:00:00Z');
    const b2End = new Date('2026-10-10T10:00:00Z');

    const overlap = availabilityService.isIntervalOverlapping(b1Start, b1End, b2Start, b2End);
    expect(overlap).toBe(false);
  });

  // 7. Cancelled booking releases inventory
  it('7. should NOT treat CANCELLED bookings as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    // Prisma query explicitly filters status in: [PENDING, CONFIRMED, HANDOVER_READY, ONGOING, RETURN_PENDING]
    // so CANCELLED is not returned by the database
    prismaMock.booking.findMany.mockResolvedValueOnce([]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);
    expect(result.available).toBe(true);
  });

  // 8. Expired booking releases inventory
  it('8. should NOT treat EXPIRED bookings as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);
    expect(result.available).toBe(true);
  });

  // 9. Completed rental releases inventory
  it('9. should NOT treat COMPLETED bookings as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);
    expect(result.available).toBe(true);
  });

  // 10. Maintenance blocks booking
  it('10. should treat scheduled MAINTENANCE blocks as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.vehicleBlock.findMany.mockResolvedValueOnce([
      {
        id: 'block-maint-001',
        blockType: VehicleBlockType.MAINTENANCE,
        startDate: start,
        endDate: end,
        reason: 'Scheduled 50,000 km general overhaul',
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(false);
    expect(result.conflicts[0].type).toBe('MAINTENANCE');
    expect(result.conflicts[0].reason).toContain('Scheduled 50,000 km general overhaul');
  });

  // 11. Admin block prevents booking
  it('11. should treat ADMINISTRATIVE blocks as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.vehicleBlock.findMany.mockResolvedValueOnce([
      {
        id: 'block-admin-001',
        blockType: VehicleBlockType.ADMIN_HOLD,
        startDate: start,
        endDate: end,
        reason: 'Compliance review on registration documents',
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(false);
    expect(result.conflicts[0].type).toBe('BLOCK');
  });

  // 12. Vendor block prevents booking
  it('12. should treat VENDOR blackout blocks as conflicts', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.vehicleBlock.findMany.mockResolvedValueOnce([
      {
        id: 'block-vendor-001',
        blockType: VehicleBlockType.VENDOR_BLACKOUT,
        startDate: start,
        endDate: end,
        reason: 'Vendor personal use',
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end);

    expect(result.available).toBe(false);
    expect(result.conflicts[0].type).toBe('BLOCK');
  });

  // 13. Duplicate reservation request is idempotent
  it('13. should return existing active hold idempotently when idempotencyKey matches', async () => {
    const existingHold = {
      id: 'hold-existing-001',
      carId: mockCar.id,
      customerId: 'cust-uuid-001',
      status: VehicleHoldStatus.ACTIVE,
      expiresAt: new Date(Date.now() + 600000),
      idempotencyKey: 'idem-key-abc-123',
    };

    prismaMock.vehicleHold.findUnique.mockResolvedValueOnce(existingHold);

    const hold = await availabilityService.createHold(
      mockCar.id,
      'cust-uuid-001',
      new Date('2026-10-01T10:00:00Z'),
      new Date('2026-10-05T10:00:00Z'),
      900,
      'idem-key-abc-123',
    );

    expect(hold).toEqual(existingHold);
    expect(lockServiceMock.acquireLock).not.toHaveBeenCalled();
  });

  // 14. Concurrent reservation attempts (locking)
  it('14. should acquire and release distributed lock during hold creation', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.vehicleHold.create.mockResolvedValueOnce({
      id: 'hold-new-002',
      carId: mockCar.id,
      status: VehicleHoldStatus.ACTIVE,
    });

    await availabilityService.createHold(mockCar.id, 'cust-uuid-001', start, end);

    expect(lockServiceMock.acquireLock).toHaveBeenCalledWith(mockCar.id);
    expect(lockServiceMock.releaseLock).toHaveBeenCalledWith(mockCar.id, 'test-lock-token');
  });

  // 15. Concurrent booking/block race (blocking car when active booking exists throws 409)
  it('15. should throw ConflictException if vendor tries to block vehicle during active booking', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([
      {
        id: 'booking-racing-001',
        status: BookingStatus.CONFIRMED,
        startDate: start,
        endDate: end,
      },
    ]);

    await expect(
      availabilityService.blockVehicle(
        mockCar.id,
        mockCar.vendorId,
        start,
        end,
        VehicleBlockType.VENDOR_BLACKOUT,
        'Personal trip',
        'user-vendor-101',
        Role.VENDOR,
      ),
    ).rejects.toThrow(ConflictException);

    expect(lockServiceMock.releaseLock).toHaveBeenCalled();
  });

  // 16. Concurrent booking/maintenance race
  it('16. should reject maintenance block if an overlapping active booking is found', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.booking.findMany.mockResolvedValueOnce([
      {
        id: 'booking-maint-race-002',
        status: BookingStatus.PENDING,
        startDate: start,
        endDate: end,
      },
    ]);

    await expect(
      availabilityService.blockVehicle(
        mockCar.id,
        mockCar.vendorId,
        start,
        end,
        VehicleBlockType.MAINTENANCE,
        'Emergency Brake Pad Service',
        'user-vendor-101',
        Role.VENDOR,
      ),
    ).rejects.toThrow(ConflictException);
  });

  // 17. Multi-instance Redis lock behavior
  it('17. should release distributed lock even if availability check fails inside hold creation', async () => {
    prismaMock.car.findUnique.mockResolvedValueOnce({
      ...mockCar,
      isAvailable: false,
    });

    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    await expect(
      availabilityService.createHold(mockCar.id, 'cust-uuid-001', start, end),
    ).rejects.toThrow(ConflictException);

    expect(lockServiceMock.acquireLock).toHaveBeenCalledWith(mockCar.id);
    expect(lockServiceMock.releaseLock).toHaveBeenCalledWith(mockCar.id, 'test-lock-token');
  });

  // 18. Tenant isolation
  it('18. should prevent vendor from blocking vehicle belonging to a different vendor (tenant isolation)', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    await expect(
      availabilityService.blockVehicle(
        mockCar.id,
        'attacker-vendor-999', // Different vendor
        start,
        end,
        VehicleBlockType.VENDOR_BLACKOUT,
        'Malicious block attempt',
        'attacker-user-999',
        Role.VENDOR,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  // 19. RBAC enforcement
  it('19. should prevent CUSTOMER role from creating vehicle blocks', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    await expect(
      availabilityService.blockVehicle(
        mockCar.id,
        mockCar.vendorId,
        start,
        end,
        VehicleBlockType.VENDOR_BLACKOUT,
        'Attempt by customer',
        'customer-123',
        Role.CUSTOMER,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  // 20. Location constraints
  it('20. should flag LOCATION_CLOSURE conflict when pickup hub has holiday/closure exception', async () => {
    const start = new Date('2026-10-02T10:00:00Z');
    const end = new Date('2026-10-04T10:00:00Z');

    prismaMock.locationException.findMany.mockResolvedValueOnce([
      {
        id: 'loc-exc-001',
        locationId: mockCar.pickupHubId,
        date: new Date('2026-10-02T00:00:00Z'),
        isClosed: true,
        reason: 'Gandhi Jayanti Public Holiday Closure',
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end, {
      hubId: mockCar.pickupHubId,
    });

    expect(result.available).toBe(false);
    expect(result.conflicts[0].type).toBe('LOCATION_CLOSURE');
    expect(result.conflicts[0].reason).toContain('Gandhi Jayanti');
  });

  // 21. API validation
  it('21. should reject invalid date range where startDate >= endDate', async () => {
    const start = new Date('2026-10-05T10:00:00Z');
    const end = new Date('2026-10-01T10:00:00Z'); // Reversed!

    await expect(availabilityService.checkAvailability(mockCar.id, start, end)).rejects.toThrow(
      BadRequestException,
    );
  });

  // 22. Stale availability handling
  it('22. should allow customer to proceed if the only active hold belongs to THEMSELVES', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');
    const myCustomerId = 'cust-my-account-123';

    // Hold belongs to this customer
    prismaMock.vehicleHold.findMany.mockResolvedValueOnce([
      {
        id: 'hold-self-001',
        carId: mockCar.id,
        customerId: myCustomerId,
        status: VehicleHoldStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 600000),
        startDate: start,
        endDate: end,
      },
    ]);

    const result = await availabilityService.checkAvailability(mockCar.id, start, end, {
      actorId: myCustomerId,
    });

    // Should NOT conflict with self hold!
    expect(result.available).toBe(true);
    expect(result.conflicts).toHaveLength(0);
  });

  // 23. Lifecycle integration (converting hold to converted)
  it('23. should convert active holds to CONVERTED upon booking completion', async () => {
    await availabilityService.convertHoldToBooking(mockCar.id, 'cust-uuid-101');

    expect(prismaMock.vehicleHold.updateMany).toHaveBeenCalledWith({
      where: {
        carId: mockCar.id,
        customerId: 'cust-uuid-101',
        status: VehicleHoldStatus.ACTIVE,
      },
      data: {
        status: VehicleHoldStatus.CONVERTED,
      },
    });
  });

  // 24. Timeline chronological aggregation
  it('24. should assemble chronological availability timeline containing bookings, blocks, and holds', async () => {
    const start = new Date('2026-10-01T00:00:00Z');
    const end = new Date('2026-10-20T00:00:00Z');

    prismaMock.car.findUnique.mockResolvedValueOnce({
      id: mockCar.id,
      bookings: [
        {
          id: 'b-1',
          status: BookingStatus.CONFIRMED,
          startDate: new Date('2026-10-05T10:00:00Z'),
          endDate: new Date('2026-10-08T10:00:00Z'),
          customerId: 'cust-1',
          totalFare: 5000,
        },
      ],
      blocks: [
        {
          id: 'blk-1',
          blockType: VehicleBlockType.MAINTENANCE,
          startDate: new Date('2026-10-01T10:00:00Z'),
          endDate: new Date('2026-10-03T10:00:00Z'),
          reason: 'Brake servicing',
        },
      ],
      holds: [
        {
          id: 'h-1',
          status: VehicleHoldStatus.ACTIVE,
          startDate: new Date('2026-10-12T10:00:00Z'),
          endDate: new Date('2026-10-15T10:00:00Z'),
          expiresAt: new Date(Date.now() + 600000),
        },
      ],
    });

    const timeline = await availabilityService.getVehicleAvailabilityTimeline(mockCar.id, start, end);

    expect(timeline).toHaveLength(3);
    // Chronological order: block (Oct 1) -> booking (Oct 5) -> hold (Oct 12)
    expect(timeline[0].type).toBe('MAINTENANCE');
    expect(timeline[1].type).toBe('BOOKING');
    expect(timeline[2].type).toBe('HOLD');
  });

  // 25. Realtime event emission
  it('25. should emit VEHICLE_BLOCKED event to vendor user on successful block creation', async () => {
    const start = new Date('2026-10-01T10:00:00Z');
    const end = new Date('2026-10-05T10:00:00Z');

    prismaMock.vehicleBlock.create.mockResolvedValueOnce({
      id: 'block-rt-001',
      carId: mockCar.id,
      startDate: start,
      endDate: end,
      blockType: VehicleBlockType.VENDOR_BLACKOUT,
    });

    await availabilityService.blockVehicle(
      mockCar.id,
      mockCar.vendorId,
      start,
      end,
      VehicleBlockType.VENDOR_BLACKOUT,
      'Vendor holiday',
      'user-vendor-101',
      Role.VENDOR,
    );

    expect(realtimeMock.emitToUser).toHaveBeenCalledWith(
      'user-vendor-101',
      'notification',
      expect.objectContaining({
        eventType: 'VEHICLE_BLOCKED',
        carId: mockCar.id,
        blockId: 'block-rt-001',
      }),
    );
  });
});
