import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import {
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  Role,
  BookingStatus,
  VehicleBlockType,
  Prisma,
} from '@prisma/client';
import { CreateCarDto } from './dto/create-car.dto';
import { UpdateCarDto } from './dto/update-car.dto';
import {
  AssignServiceAreaDto,
  StartMaintenanceDto,
  CompleteMaintenanceDto,
  AdminVerifyVehicleDto,
  AdminRejectVehicleDto,
  AdminSuspendVehicleDto,
  AdminRetireVehicleDto,
  AdminFleetQueryDto,
} from './dto/vendor-fleet.dto';
import { VehicleLifecycleService, LifecycleActor } from './vehicle-lifecycle.service';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';
import { PaginatedResult } from '../common/pagination.dto';

@Injectable()
export class VendorFleetService {
  private readonly logger = new Logger(VendorFleetService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycleService: VehicleLifecycleService,
    private readonly eligibilityService: VehicleOperationsEligibilityService,
    @Optional() private readonly cacheService?: RedisCacheService,
  ) {}

  /**
   * Resolves vendor profile from a user ID.
   */
  async getVendorByUserId(userId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { userId },
    });
    if (!vendor) {
      throw new ForbiddenException('User is not registered as a vendor.');
    }
    return vendor;
  }

  /**
   * 1. CREATE VEHICLE (Vendor)
   * Creates vehicle in DRAFT status, unverified, unbookable until verification and activation.
   */
  async createVehicle(userId: string, dto: CreateCarDto) {
    const vendor = await this.getVendorByUserId(userId);

    // Duplicate registration plate validation
    const existing = await this.prisma.car.findFirst({
      where: { registrationNumber: dto.registrationNumber.trim() },
    });
    if (existing) {
      throw new ConflictException(
        `A vehicle with registration number '${dto.registrationNumber}' already exists.`,
      );
    }

    // Service area authorization check
    if (dto.serviceAreaId) {
      const assignment = await this.prisma.vendorServiceArea.findUnique({
        where: {
          vendorId_serviceAreaId: {
            vendorId: vendor.id,
            serviceAreaId: dto.serviceAreaId,
          },
        },
      });
      if (!assignment || !assignment.isActive) {
        throw new BadRequestException(
          'Vendor is not authorized to deploy vehicles in the specified service area.',
        );
      }
    }

    const car = await this.prisma.$transaction(async (tx) => {
      const created = await tx.car.create({
        data: {
          vendorId: vendor.id,
          make: dto.make,
          model: dto.model,
          year: dto.year,
          type: dto.type,
          fuelType: dto.fuelType,
          seating: dto.seating,
          isAC: dto.isAC,
          registrationNumber: dto.registrationNumber.trim().toUpperCase(),
          photos: dto.photos || [],
          pricePerKm: new Prisma.Decimal(dto.pricePerKm),
          pricePerDay: new Prisma.Decimal(dto.pricePerDay),
          pricePerHour: new Prisma.Decimal(dto.pricePerHour),
          isAvailable: false, // Never bookable on creation
          operationalStatus: VehicleOperationalStatus.DRAFT,
          verificationStatus: VehicleVerificationStatus.PENDING,
          availableTripTypes: dto.availableTripTypes || [],
          pickupHubId: dto.pickupHubId || null,
          serviceAreaId: dto.serviceAreaId || null,
        },
        include: {
          vendor: true,
          serviceArea: true,
        },
      });

      await tx.vehicleAuditLog.create({
        data: {
          carId: created.id,
          actorId: userId,
          actorRole: Role.VENDOR,
          action: 'CREATE_VEHICLE',
          fromStatus: null,
          toStatus: VehicleOperationalStatus.DRAFT,
          reason: 'Initial vehicle registration',
        },
      });

      return created;
    });

    if (this.cacheService) {
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_FLEET(vendor.id));
      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.FLEET_KPI());
    }

    return car;
  }

  /**
   * 2. UPDATE VEHICLE (Vendor or Admin)
   */
  async updateVehicle(carId: string, actor: LifecycleActor, dto: UpdateCarDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    // Ownership check for vendor
    if (actor.role === Role.VENDOR && actor.vendorId && car.vendorId !== actor.vendorId) {
      throw new ForbiddenException('You do not have permission to modify this vehicle.');
    }

    // State protection: RETIRED vehicles cannot be modified
    if (car.operationalStatus === VehicleOperationalStatus.RETIRED) {
      throw new BadRequestException('Retired vehicles cannot be modified.');
    }

    // Duplicate registration check
    if (dto.registrationNumber && dto.registrationNumber.trim() !== car.registrationNumber) {
      const duplicate = await this.prisma.car.findFirst({
        where: {
          registrationNumber: dto.registrationNumber.trim().toUpperCase(),
          id: { not: carId },
        },
      });
      if (duplicate) {
        throw new ConflictException(
          `A vehicle with registration number '${dto.registrationNumber}' already exists.`,
        );
      }
    }

    // Service area authorization check
    if (dto.serviceAreaId && dto.serviceAreaId !== car.serviceAreaId) {
      const assignment = await this.prisma.vendorServiceArea.findUnique({
        where: {
          vendorId_serviceAreaId: {
            vendorId: car.vendorId,
            serviceAreaId: dto.serviceAreaId,
          },
        },
      });
      if (!assignment || !assignment.isActive) {
        throw new BadRequestException(
          'Vendor is not authorized to deploy vehicles in the specified service area.',
        );
      }
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.car.update({
        where: { id: carId },
        data: {
          ...(dto.make ? { make: dto.make } : {}),
          ...(dto.model ? { model: dto.model } : {}),
          ...(dto.year ? { year: dto.year } : {}),
          ...(dto.type ? { type: dto.type } : {}),
          ...(dto.fuelType ? { fuelType: dto.fuelType } : {}),
          ...(dto.seating !== undefined ? { seating: dto.seating } : {}),
          ...(dto.isAC !== undefined ? { isAC: dto.isAC } : {}),
          ...(dto.registrationNumber
            ? { registrationNumber: dto.registrationNumber.trim().toUpperCase() }
            : {}),
          ...(dto.photos ? { photos: dto.photos } : {}),
          ...(dto.pricePerKm !== undefined
            ? { pricePerKm: new Prisma.Decimal(dto.pricePerKm) }
            : {}),
          ...(dto.pricePerDay !== undefined
            ? { pricePerDay: new Prisma.Decimal(dto.pricePerDay) }
            : {}),
          ...(dto.pricePerHour !== undefined
            ? { pricePerHour: new Prisma.Decimal(dto.pricePerHour) }
            : {}),
          ...(dto.availableTripTypes ? { availableTripTypes: dto.availableTripTypes } : {}),
          ...(dto.pickupHubId !== undefined ? { pickupHubId: dto.pickupHubId } : {}),
          ...(dto.serviceAreaId !== undefined ? { serviceAreaId: dto.serviceAreaId } : {}),
        },
        include: {
          vendor: true,
          serviceArea: true,
        },
      });

      await tx.vehicleAuditLog.create({
        data: {
          carId,
          actorId: actor.id,
          actorRole: actor.role,
          action: 'UPDATE_VEHICLE',
          fromStatus: car.operationalStatus,
          toStatus: car.operationalStatus,
          reason: 'Vehicle details updated',
        },
      });

      return result;
    });

    await this.lifecycleService.invalidateCaches(carId, car.vendorId);
    return updated;
  }

  /**
   * 3. SUBMIT VEHICLE FOR VERIFICATION (Vendor)
   */
  async submitForVerification(carId: string, actor: LifecycleActor) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true, documents: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    if (actor.role === Role.VENDOR && actor.vendorId && car.vendorId !== actor.vendorId) {
      throw new ForbiddenException('You do not have permission to submit this vehicle.');
    }

    if (car.operationalStatus !== VehicleOperationalStatus.DRAFT) {
      throw new BadRequestException(
        `Only vehicles in DRAFT status can be submitted for verification. Current status is ${car.operationalStatus}.`,
      );
    }

    // Minimum metadata completeness validation
    if (!car.registrationNumber || car.registrationNumber.trim() === '') {
      throw new BadRequestException('Vehicle must have a registration plate number.');
    }
    if (!car.photos || car.photos.length === 0) {
      throw new BadRequestException('Vehicle must have at least one photo before verification.');
    }

    await this.prisma.car.update({
      where: { id: carId },
      data: {
        verificationStatus: VehicleVerificationStatus.PENDING,
        rejectionReason: null,
      },
    });

    return await this.lifecycleService.transitionStatus(
      carId,
      VehicleOperationalStatus.PENDING_VERIFICATION,
      actor,
      { reason: 'Submitted by vendor for platform verification review' },
    );
  }

  /**
   * 4. ASSIGN SERVICE AREA (Vendor or Admin)
   */
  async assignServiceArea(carId: string, actor: LifecycleActor, dto: AssignServiceAreaDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    if (actor.role === Role.VENDOR && actor.vendorId && car.vendorId !== actor.vendorId) {
      throw new ForbiddenException('You do not have permission to modify this vehicle.');
    }

    // Service Area authorization verification
    const serviceArea = await this.prisma.serviceArea.findUnique({
      where: { id: dto.serviceAreaId },
    });
    if (!serviceArea) {
      throw new NotFoundException(`Service area with ID ${dto.serviceAreaId} not found.`);
    }

    const assignment = await this.prisma.vendorServiceArea.findUnique({
      where: {
        vendorId_serviceAreaId: {
          vendorId: car.vendorId,
          serviceAreaId: dto.serviceAreaId,
        },
      },
    });
    if (!assignment || !assignment.isActive) {
      throw new BadRequestException(
        `Vendor is not authorized to operate in service area '${serviceArea.name}'.`,
      );
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const c = await tx.car.update({
        where: { id: carId },
        data: { serviceAreaId: dto.serviceAreaId },
        include: { serviceArea: true },
      });

      await tx.vehicleAuditLog.create({
        data: {
          carId,
          actorId: actor.id,
          actorRole: actor.role,
          action: 'ASSIGN_SERVICE_AREA',
          fromStatus: car.operationalStatus,
          toStatus: car.operationalStatus,
          reason: `Assigned to service area ${serviceArea.name} (${dto.serviceAreaId})`,
        },
      });

      return c;
    });

    await this.lifecycleService.invalidateCaches(carId, car.vendorId);
    return updated;
  }

  /**
   * 5. START MAINTENANCE (Vendor or Admin)
   * Immediately takes vehicle out of service, creates a VehicleBlock, and checks booking conflicts.
   */
  async startMaintenance(carId: string, actor: LifecycleActor, dto: StartMaintenanceDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    if (actor.role === Role.VENDOR && actor.vendorId && car.vendorId !== actor.vendorId) {
      throw new ForbiddenException('You do not have permission to place this vehicle in maintenance.');
    }

    if (
      car.operationalStatus === VehicleOperationalStatus.RETIRED ||
      car.operationalStatus === VehicleOperationalStatus.SUSPENDED
    ) {
      throw new BadRequestException(
        `Cannot initiate maintenance on vehicle in status ${car.operationalStatus}.`,
      );
    }

    const now = new Date();
    const returnDate = dto.expectedReturnDate
      ? new Date(dto.expectedReturnDate)
      : new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    // Active booking conflict check
    const conflictingBookings = await this.prisma.booking.findMany({
      where: {
        carId,
        status: {
          in: [BookingStatus.CONFIRMED, BookingStatus.HANDOVER_READY, BookingStatus.ONGOING],
        },
        startDate: { lt: returnDate },
        endDate: { gt: now },
      },
    });

    const ongoingBooking = conflictingBookings.find(
      (b) => b.status === BookingStatus.ONGOING,
    );
    if (ongoingBooking) {
      throw new ConflictException(
        `Cannot start maintenance while a rental is currently ONGOING with a customer (Booking ID: ${ongoingBooking.id}).`,
      );
    }

    if (conflictingBookings.length > 0 && !dto.overrideConflictingBookings) {
      const ids = conflictingBookings.map((b) => b.id).join(', ');
      throw new ConflictException(
        `Maintenance overlaps with ${conflictingBookings.length} active booking(s): [${ids}]. Resolve or override conflicts first.`,
      );
    }

    // Execute block and status transition in transaction
    const updated = await this.prisma.$transaction(async (tx) => {
      // 1. Create a maintenance block record
      await tx.vehicleBlock.create({
        data: {
          carId,
          vendorId: car.vendorId,
          blockType: VehicleBlockType.MAINTENANCE,
          reason: dto.reason,
          startDate: now,
          endDate: returnDate,
          actorId: actor.id,
          actorRole: actor.role,
        },
      });

      // 2. Update Car maintenance fields
      await tx.car.update({
        where: { id: carId },
        data: {
          maintenanceReason: dto.reason,
          maintenanceStartedAt: now,
          expectedReturnDate: dto.expectedReturnDate ? new Date(dto.expectedReturnDate) : null,
          isAvailable: false,
        },
      });

      // 3. Log audit
      await tx.vehicleAuditLog.create({
        data: {
          carId,
          actorId: actor.id,
          actorRole: actor.role,
          action: 'START_MAINTENANCE',
          fromStatus: car.operationalStatus,
          toStatus: VehicleOperationalStatus.MAINTENANCE,
          reason: dto.reason,
          metadata: { expectedReturnDate: dto.expectedReturnDate },
        },
      });

      return await tx.car.update({
        where: { id: carId },
        data: { operationalStatus: VehicleOperationalStatus.MAINTENANCE },
      });
    });

    await this.lifecycleService.invalidateCaches(carId, car.vendorId);
    return updated;
  }

  /**
   * 6. COMPLETE MAINTENANCE (Vendor or Admin)
   * Resolves maintenance block and returns vehicle to operational eligibility.
   */
  async completeMaintenance(carId: string, actor: LifecycleActor, dto: CompleteMaintenanceDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    if (actor.role === Role.VENDOR && actor.vendorId && car.vendorId !== actor.vendorId) {
      throw new ForbiddenException('You do not have permission to modify this vehicle.');
    }

    if (car.operationalStatus !== VehicleOperationalStatus.MAINTENANCE) {
      throw new BadRequestException('Vehicle is not currently in maintenance.');
    }

    // Resolve active maintenance blocks
    await this.prisma.vehicleBlock.deleteMany({
      where: {
        carId,
        blockType: VehicleBlockType.MAINTENANCE,
      },
    });

    // Clear car maintenance details
    await this.prisma.car.update({
      where: { id: carId },
      data: {
        operationalStatus: VehicleOperationalStatus.INACTIVE,
        maintenanceReason: null,
        maintenanceStartedAt: null,
        expectedReturnDate: null,
      },
    });

    // Check server-authoritative operational eligibility
    const eligibility = await this.eligibilityService.evaluateEligibility(carId, {
      skipCache: true,
    });

    const targetStatus = eligibility.eligible
      ? VehicleOperationalStatus.ACTIVE
      : VehicleOperationalStatus.INACTIVE;

    const updated = await this.lifecycleService.transitionStatus(carId, targetStatus, actor, {
      reason: dto.notes || 'Maintenance completed',
      skipEligibilityCheck: true, // We just checked it
    });

    return {
      vehicle: updated,
      eligibility,
      note: eligibility.eligible
        ? 'Vehicle returned directly to ACTIVE operational status.'
        : 'Vehicle moved to INACTIVE status due to pending operational blockers.',
    };
  }

  /**
   * 7. ADMIN VERIFY VEHICLE (Admin)
   * Sets verificationStatus = VERIFIED.
   */
  async adminVerifyVehicle(carId: string, adminUserId: string, dto: AdminVerifyVehicleDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      await tx.car.update({
        where: { id: carId },
        data: {
          verificationStatus: VehicleVerificationStatus.VERIFIED,
          verifiedAt: now,
          reviewedByUserId: adminUserId,
          rejectionReason: null,
        },
      });

      await tx.vehicleAuditLog.create({
        data: {
          carId,
          actorId: adminUserId,
          actorRole: Role.ADMIN,
          action: 'ADMIN_VERIFY_VEHICLE',
          fromStatus: car.operationalStatus,
          toStatus: car.operationalStatus,
          reason: dto.notes || 'Vehicle verified by admin',
        },
      });
    });

    // Evaluate operational readiness
    const eligibility = await this.eligibilityService.evaluateEligibility(carId, {
      skipCache: true,
    });

    let finalCar: any = car;
    if (dto.autoActivate !== false && eligibility.eligible) {
      finalCar = await this.lifecycleService.transitionStatus(
        carId,
        VehicleOperationalStatus.ACTIVE,
        { id: adminUserId, role: Role.ADMIN },
        { reason: 'Auto-activated following administrative verification approval' },
      );
    } else if (car.operationalStatus === VehicleOperationalStatus.PENDING_VERIFICATION) {
      finalCar = await this.lifecycleService.transitionStatus(
        carId,
        VehicleOperationalStatus.INACTIVE,
        { id: adminUserId, role: Role.ADMIN },
        { reason: 'Verified but requires vendor activation' },
      );
    }

    await this.lifecycleService.invalidateCaches(carId, car.vendorId);
    return {
      vehicle: finalCar,
      eligibility,
    };
  }

  /**
   * 8. ADMIN REJECT VEHICLE (Admin)
   * Rejects verification and moves car back to DRAFT with rejection reason.
   */
  async adminRejectVehicle(carId: string, adminUserId: string, dto: AdminRejectVehicleDto) {
    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.car.update({
        where: { id: carId },
        data: {
          verificationStatus: VehicleVerificationStatus.REJECTED,
          rejectionReason: dto.reason,
          reviewedByUserId: adminUserId,
          operationalStatus: VehicleOperationalStatus.DRAFT,
          isAvailable: false,
        },
      });

      await tx.vehicleAuditLog.create({
        data: {
          carId,
          actorId: adminUserId,
          actorRole: Role.ADMIN,
          action: 'ADMIN_REJECT_VEHICLE',
          fromStatus: car.operationalStatus,
          toStatus: VehicleOperationalStatus.DRAFT,
          reason: dto.reason,
        },
      });
    });

    await this.lifecycleService.invalidateCaches(carId, car.vendorId);

    return await this.prisma.car.findUnique({
      where: { id: carId },
      include: { vendor: true },
    });
  }

  /**
   * 9. ADMIN SUSPEND VEHICLE (Admin)
   */
  async adminSuspendVehicle(carId: string, adminUserId: string, dto: AdminSuspendVehicleDto) {
    return await this.lifecycleService.transitionStatus(
      carId,
      VehicleOperationalStatus.SUSPENDED,
      { id: adminUserId, role: Role.ADMIN },
      { reason: dto.reason },
    );
  }

  /**
   * 10. ADMIN RETIRE VEHICLE (Admin)
   */
  async adminRetireVehicle(carId: string, adminUserId: string, dto: AdminRetireVehicleDto) {
    // Check if ongoing bookings exist
    const ongoingBookings = await this.prisma.booking.findMany({
      where: {
        carId,
        status: { in: [BookingStatus.HANDOVER_READY, BookingStatus.ONGOING] },
      },
    });

    if (ongoingBookings.length > 0) {
      throw new ConflictException(
        `Cannot retire vehicle with ${ongoingBookings.length} ongoing trip(s) in progress.`,
      );
    }

    return await this.lifecycleService.transitionStatus(
      carId,
      VehicleOperationalStatus.RETIRED,
      { id: adminUserId, role: Role.ADMIN },
      { reason: dto.reason },
    );
  }

  /**
   * 11. GET FLEET KPIS (Admin & Platform Console)
   */
  async getFleetKPIs() {
    const cacheKey = REDIS_NAMESPACES.CACHE.FLEET_KPI();

    if (this.cacheService) {
      const cached = await this.cacheService.get(cacheKey);
      if (cached) return cached;
    }

    const [
      total,
      active,
      pendingVerification,
      maintenance,
      suspended,
      inactive,
      retired,
      verifiedCount,
      unverifiedCount,
    ] = await Promise.all([
      this.prisma.car.count(),
      this.prisma.car.count({ where: { operationalStatus: VehicleOperationalStatus.ACTIVE } }),
      this.prisma.car.count({
        where: { operationalStatus: VehicleOperationalStatus.PENDING_VERIFICATION },
      }),
      this.prisma.car.count({
        where: { operationalStatus: VehicleOperationalStatus.MAINTENANCE },
      }),
      this.prisma.car.count({
        where: { operationalStatus: VehicleOperationalStatus.SUSPENDED },
      }),
      this.prisma.car.count({
        where: { operationalStatus: VehicleOperationalStatus.INACTIVE },
      }),
      this.prisma.car.count({
        where: { operationalStatus: VehicleOperationalStatus.RETIRED },
      }),
      this.prisma.car.count({
        where: { verificationStatus: VehicleVerificationStatus.VERIFIED },
      }),
      this.prisma.car.count({
        where: { verificationStatus: VehicleVerificationStatus.PENDING },
      }),
    ]);

    const kpis = {
      total,
      active,
      pendingVerification,
      maintenance,
      suspended,
      inactive,
      retired,
      verifiedCount,
      unverifiedCount,
      operationalReadinessRate: total > 0 ? Number(((active / total) * 100).toFixed(1)) : 0,
    };

    if (this.cacheService) {
      await this.cacheService.set(cacheKey, kpis, DEFAULT_CACHE_TTLS.SHORT_TERM);
    }

    return kpis;
  }

  /**
   * 12. ADMIN FLEET QUERY (Admin)
   */
  async getAdminFleet(query: AdminFleetQueryDto): Promise<PaginatedResult<any>> {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.CarWhereInput = {};

    if (query.vendorId) {
      where.vendorId = query.vendorId;
    }

    if (query.serviceAreaId) {
      where.serviceAreaId = query.serviceAreaId;
    }

    if (query.city) {
      where.vendor = {
        city: { equals: query.city, mode: 'insensitive' },
      };
    }

    if (query.operationalStatus) {
      where.operationalStatus = query.operationalStatus;
    }

    if (query.verificationStatus) {
      where.verificationStatus = query.verificationStatus;
    }

    if (query.search) {
      const term = query.search.trim();
      where.OR = [
        { make: { contains: term, mode: 'insensitive' } },
        { model: { contains: term, mode: 'insensitive' } },
        { registrationNumber: { contains: term, mode: 'insensitive' } },
        { vendor: { businessName: { contains: term, mode: 'insensitive' } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.car.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          vendor: {
            select: {
              id: true,
              businessName: true,
              ownerName: true,
              city: true,
              verificationStatus: true,
            },
          },
          serviceArea: {
            select: {
              id: true,
              name: true,
              status: true,
            },
          },
        },
      }),
      this.prisma.car.count({ where }),
    ]);

    return {
      data: items,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 13. VENDOR FLEET QUERY (Vendor)
   */
  async getVendorFleet(userId: string) {
    const vendor = await this.getVendorByUserId(userId);

    const cars = await this.prisma.car.findMany({
      where: { vendorId: vendor.id },
      orderBy: { createdAt: 'desc' },
      include: {
        serviceArea: true,
        documents: true,
      },
    });

    return {
      vendorId: vendor.id,
      businessName: vendor.businessName,
      cars,
    };
  }

  /**
   * 14. GET VEHICLE AUDIT LOGS
   */
  async getVehicleAuditLogs(carId: string) {
    return await this.prisma.vehicleAuditLog.findMany({
      where: { carId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
