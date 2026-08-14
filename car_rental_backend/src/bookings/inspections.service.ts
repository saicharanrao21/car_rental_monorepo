import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { InspectionType, BookingStatus, Role, Prisma } from '@prisma/client';
import { CreateInspectionDto } from './dto/create-inspection.dto';
import { UploadsService } from '../uploads/uploads.service';

@Injectable()
export class InspectionsService {
  private readonly logger = new Logger(InspectionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly uploadsService: UploadsService,
  ) {}

  /**
   * Creates or updates a vehicle inspection (PRE_TRIP or POST_TRIP).
   * Enforces immutability once finalized and validates monotonic odometer readings.
   */
  async upsertInspection(
    bookingId: string,
    dto: CreateInspectionDto,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        vendor: true,
        customer: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isVendor = booking.vendor.userId === requestingUser.userId;

    if (!isAdmin && !isVendor) {
      throw new ForbiddenException(
        'Access denied: Only the fleet owner or admin can record vehicle inspections.',
      );
    }

    // Booking lifecycle validation
    if (dto.type === InspectionType.PRE_TRIP) {
      if (
        booking.status !== BookingStatus.CONFIRMED &&
        booking.status !== BookingStatus.PENDING
      ) {
        throw new BadRequestException(
          `Pre-trip inspection can only be recorded for CONFIRMED bookings. Current status: ${booking.status}`,
        );
      }
    } else if (dto.type === InspectionType.POST_TRIP) {
      if (booking.status !== BookingStatus.ONGOING) {
        throw new BadRequestException(
          `Post-trip inspection can only be recorded for ONGOING bookings. Current status: ${booking.status}`,
        );
      }

      // Validate post-trip odometer against pre-trip inspection
      const preTrip = await this.prisma.inspection.findUnique({
        where: {
          bookingId_type: {
            bookingId,
            type: InspectionType.PRE_TRIP,
          },
        },
      });

      if (!preTrip) {
        throw new BadRequestException(
          'Pre-trip inspection must be recorded and finalized before recording post-trip inspection.',
        );
      }

      if (new Prisma.Decimal(dto.odometer).lt(preTrip.odometer)) {
        throw new BadRequestException(
          `Return odometer reading (${dto.odometer}) cannot be less than pre-trip odometer reading (${preTrip.odometer.toNumber()}).`,
        );
      }
    }

    // Check immutability if inspection already exists
    const existing = await this.prisma.inspection.findUnique({
      where: {
        bookingId_type: {
          bookingId,
          type: dto.type,
        },
      },
    });

    if (existing && existing.finalized) {
      throw new BadRequestException(
        `${dto.type} inspection has already been finalized and cannot be modified.`,
      );
    }

    const isFinalizing = dto.finalize === true;

    return this.prisma.inspection.upsert({
      where: {
        bookingId_type: {
          bookingId,
          type: dto.type,
        },
      },
      create: {
        bookingId,
        type: dto.type,
        performedById: requestingUser.userId,
        odometer: new Prisma.Decimal(dto.odometer),
        fuelPercent: dto.fuelPercent,
        conditionNotes: dto.conditionNotes || null,
        damagePhotos: dto.damagePhotos || [],
        finalized: isFinalizing,
        finalizedAt: isFinalizing ? new Date() : null,
      },
      update: {
        odometer: new Prisma.Decimal(dto.odometer),
        fuelPercent: dto.fuelPercent,
        conditionNotes: dto.conditionNotes || null,
        damagePhotos: dto.damagePhotos || [],
        finalized: isFinalizing,
        finalizedAt: isFinalizing ? new Date() : null,
        performedById: requestingUser.userId,
      },
    });
  }

  /**
   * Retrieves inspections for a booking with presigned download URLs for damage photos.
   */
  async getInspections(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        vendor: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found.');
    }

    const isAdminOrSupport =
      requestingUser.role === Role.ADMIN ||
      requestingUser.role === Role.SUPPORT_AGENT;
    const isVendor = booking.vendor.userId === requestingUser.userId;
    const isCustomer = booking.customerId === requestingUser.userId;

    if (!isAdminOrSupport && !isVendor && !isCustomer) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view inspections for this booking.',
      );
    }

    const inspections = await this.prisma.inspection.findMany({
      where: { bookingId },
      include: {
        performedBy: {
          select: {
            id: true,
            name: true,
            role: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    // Resolve short-lived presigned GET URLs for private inspection damage photos
    const resolved = await Promise.all(
      inspections.map(async (insp) => {
        const signedPhotos = await Promise.all(
          insp.damagePhotos.map((key) =>
            this.uploadsService.getPresignedDownloadUrl(key, 900),
          ),
        );
        return {
          ...insp,
          damagePhotos: signedPhotos,
          rawPhotoKeys: insp.damagePhotos,
        };
      }),
    );

    return resolved;
  }
}
