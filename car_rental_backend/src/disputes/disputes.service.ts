import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { AddEvidenceDto } from './dto/add-evidence.dto';
import { UpdateDisputeDto } from './dto/update-dispute.dto';
import { DisputeStatus, Role } from '@prisma/client';
import { AuditLogService } from '../admin/audit-log.service';
import { PaginationDto } from '../common/pagination.dto';

@Injectable()
export class DisputesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async createDispute(userId: string, dto: CreateDisputeDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: dto.bookingId },
      include: { vendor: true },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    const isCustomer = booking.customerId === userId;
    const isVendor = booking.vendor?.userId === userId;

    if (!isCustomer && !isVendor) {
      throw new ForbiddenException('Only the customer or vendor on this booking can raise a dispute');
    }

    const existing = await this.prisma.dispute.findUnique({
      where: { bookingId: dto.bookingId },
    });

    if (existing) {
      return existing;
    }

    const dispute = await this.prisma.dispute.create({
      data: {
        bookingId: dto.bookingId,
        raisedByUserId: userId,
        reason: dto.reason,
        status: DisputeStatus.OPEN,
      },
    });

    await this.prisma.booking.update({
      where: { id: dto.bookingId },
      data: {
        disputeFlag: true,
        disputeNote: dto.reason,
      },
    });

    return dispute;
  }

  async addEvidence(userId: string, disputeId: string, dto: AddEvidenceDto) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        booking: {
          include: {
            vendor: true,
          },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException('Dispute not found');
    }

    const isCustomer = dispute.booking.customerId === userId;
    const isVendor = dispute.booking.vendor?.userId === userId;
    const isRaiser = dispute.raisedByUserId === userId;

    if (!isCustomer && !isVendor && !isRaiser) {
      throw new ForbiddenException('Only parties involved in this dispute can submit evidence');
    }

    return this.prisma.disputeEvidence.create({
      data: {
        disputeId,
        uploadedByUserId: userId,
        fileUrl: dto.fileUrl,
        description: dto.description || null,
      },
    });
  }

  async getDisputeById(userId: string, role: string, disputeId: string) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: {
        evidences: {
          orderBy: { createdAt: 'desc' },
        },
        booking: {
          include: {
            car: true,
            vendor: true,
            customer: {
              select: { id: true, name: true, phone: true, email: true },
            },
          },
        },
        raisedByUser: {
          select: { id: true, name: true, role: true },
        },
      },
    });

    if (!dispute) {
      throw new NotFoundException('Dispute not found');
    }

    const isAdmin = role === Role.ADMIN;
    const isCustomer = dispute.booking.customerId === userId;
    const isVendor = dispute.booking.vendor?.userId === userId;
    const isRaiser = dispute.raisedByUserId === userId;

    if (!isAdmin && !isCustomer && !isVendor && !isRaiser) {
      throw new ForbiddenException('Access denied: You are not a party to this dispute');
    }

    return dispute;
  }

  async adminUpdateDispute(adminUserId: string, disputeId: string, dto: UpdateDisputeDto) {
    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
    });

    if (!dispute) {
      throw new NotFoundException('Dispute not found');
    }

    const isResolvedOrRejected = dto.status === DisputeStatus.RESOLVED || dto.status === DisputeStatus.REJECTED;

    const updatedDispute = await this.prisma.dispute.update({
      where: { id: disputeId },
      data: {
        status: dto.status,
        resolutionNote: dto.resolutionNote ?? undefined,
        resolvedAt: isResolvedOrRejected ? new Date() : undefined,
      },
    });

    if (isResolvedOrRejected) {
      await this.prisma.booking.update({
        where: { id: dispute.bookingId },
        data: {
          disputeFlag: false,
          disputeNote: dto.resolutionNote || `Dispute ${dto.status}`,
        },
      });
    }

    this.auditLogService.log(adminUserId, 'DISPUTE_UPDATED', 'Dispute', disputeId, { status: dto.status, resolutionNote: dto.resolutionNote });

    return updatedDispute;
  }

  async adminGetDisputes(status?: DisputeStatus, pagination?: PaginationDto) {
    const page = pagination?.page || 1;
    const limit = pagination?.limit || 20;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (status) {
      where.status = status;
    }

    const [total, data] = await Promise.all([
      this.prisma.dispute.count({ where }),
      this.prisma.dispute.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          evidences: true,
          booking: {
            include: {
              car: true,
              vendor: true,
              customer: {
                select: { id: true, name: true, phone: true },
              },
            },
          },
          raisedByUser: {
            select: { id: true, name: true, role: true },
          },
        },
      }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }
}
