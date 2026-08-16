import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { KycStatus } from '@prisma/client';
import { SubmitKycDto } from './dto/submit-kyc.dto';
import { ReviewKycDto } from './dto/review-kyc.dto';

@Injectable()
export class KycService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * Submit or update Customer Driving Licence verification
   */
  async submitKyc(userId: string, dto: SubmitKycDto) {
    const existing = await this.prisma.customerKyc.findUnique({
      where: { userId },
    });

    const expiryDate = new Date(dto.expiryDate);
    if (isNaN(expiryDate.getTime()) || expiryDate < new Date()) {
      throw new BadRequestException('Driving Licence has expired or date is invalid.');
    }

    if (existing) {
      return this.prisma.customerKyc.update({
        where: { userId },
        data: {
          licenceNumber: dto.licenceNumber,
          expiryDate,
          licenceFrontUrl: dto.licenceFrontUrl,
          licenceBackUrl: dto.licenceBackUrl,
          status: KycStatus.PENDING,
          rejectionReason: null,
        },
      });
    }

    return this.prisma.customerKyc.create({
      data: {
        userId,
        licenceNumber: dto.licenceNumber,
        expiryDate,
        licenceFrontUrl: dto.licenceFrontUrl,
        licenceBackUrl: dto.licenceBackUrl,
        status: KycStatus.PENDING,
      },
    });
  }

  /**
   * Get current user KYC status
   */
  async getKycStatus(userId: string) {
    const kyc = await this.prisma.customerKyc.findUnique({
      where: { userId },
    });

    if (!kyc) {
      return { status: 'NONE', kyc: null };
    }

    // Check if expired
    if (kyc.status === KycStatus.VERIFIED && kyc.expiryDate < new Date()) {
      await this.prisma.customerKyc.update({
        where: { id: kyc.id },
        data: { status: KycStatus.EXPIRED },
      });
      return { status: KycStatus.EXPIRED, kyc: { ...kyc, status: KycStatus.EXPIRED } };
    }

    return { status: kyc.status, kyc };
  }

  /**
   * Admin: List pending KYC submissions for review
   */
  async getPendingKycSubmissions() {
    return this.prisma.customerKyc.findMany({
      where: { status: KycStatus.PENDING },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Admin: Approve or Reject a Customer KYC Submission
   */
  async reviewKyc(adminUserId: string, kycId: string, dto: ReviewKycDto) {
    const kyc = await this.prisma.customerKyc.findUnique({
      where: { id: kycId },
    });

    if (!kyc) {
      throw new NotFoundException('KYC submission not found.');
    }

    if (dto.status === KycStatus.REJECTED && !dto.rejectionReason) {
      throw new BadRequestException('Rejection reason is required when rejecting KYC.');
    }

    const updated = await this.prisma.customerKyc.update({
      where: { id: kycId },
      data: {
        status: dto.status,
        rejectionReason: dto.status === KycStatus.REJECTED ? dto.rejectionReason : null,
        verifiedAt: dto.status === KycStatus.VERIFIED ? new Date() : null,
      },
    });

    await this.auditLogService.log(
      adminUserId,
      `KYC_${dto.status}`,
      'CustomerKyc',
      kycId,
      {
        userId: kyc.userId,
        status: dto.status,
        rejectionReason: dto.rejectionReason || null,
      },
    );

    return updated;
  }
}
