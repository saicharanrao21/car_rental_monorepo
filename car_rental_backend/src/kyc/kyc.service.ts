import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';
import { UploadsService } from '../uploads/uploads.service';
import { KycStatus } from '@prisma/client';
import { SubmitKycDto } from './dto/submit-kyc.dto';
import { ReviewKycDto } from './dto/review-kyc.dto';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';

@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
    @Optional() private readonly uploadsService?: UploadsService,
    @Optional() private readonly runtimeService?: IntegrationRuntimeService,
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

    // Validate storage key ownership / sanitize prefix
    if (dto.licenceFrontUrl && (dto.licenceFrontUrl.startsWith('vendor-document/') || dto.licenceFrontUrl.includes('..'))) {
      throw new BadRequestException('Invalid licence front URL key.');
    }
    if (dto.licenceBackUrl && (dto.licenceBackUrl.startsWith('vendor-document/') || dto.licenceBackUrl.includes('..'))) {
      throw new BadRequestException('Invalid licence back URL key.');
    }

    let kycRecord;
    if (existing) {
      kycRecord = await this.prisma.customerKyc.update({
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
    } else {
      kycRecord = await this.prisma.customerKyc.create({
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

    // Attempt automated identity verification if runtime is available
    if (this.runtimeService) {
      try {
        const autoResult = await this.autoVerifyCustomerKyc(userId);
        if (autoResult.verified && autoResult.kyc) {
          return autoResult.kyc;
        }
      } catch (err: any) {
        this.logger.log(`Automated verification deferred to manual admin review: ${err.message}`);
      }
    }

    return kycRecord;
  }

  /**
   * Automated DL KYC verification via configured verification provider (Surepass, HyperVerge, etc.)
   */
  async autoVerifyCustomerKyc(userId: string) {
    const kyc = await this.prisma.customerKyc.findUnique({
      where: { userId },
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
    });

    if (!kyc) {
      throw new NotFoundException('No KYC submission found for user.');
    }

    if (!this.runtimeService) {
      this.logger.warn('IntegrationRuntimeService not available for automated KYC verification.');
      return {
        verified: false,
        status: kyc.status,
        message: 'Automated verification runtime unavailable. Manual review required.',
        kyc,
      };
    }

    try {
      const result = await this.runtimeService.execute({
        category: IntegrationCategory.IDENTITY_VERIFICATION,
        capability: 'DRIVING_LICENCE_VERIFY',
        payload: {
          licenceNumber: kyc.licenceNumber,
          fullName: kyc.user?.name || undefined,
          expiryDate: kyc.expiryDate,
        },
        idempotencyKey: `auto_kyc_${userId}_${kyc.licenceNumber}`,
        isIdempotent: true,
      });

      if (result.success && result.data?.isValid) {
        const updated = await this.prisma.customerKyc.update({
          where: { userId },
          data: {
            status: KycStatus.VERIFIED,
            verifiedAt: new Date(),
            rejectionReason: null,
          },
        });

        await this.auditLogService.log(
          'system',
          'KYC_VERIFIED_AUTOMATED',
          'CustomerKyc',
          kyc.id,
          {
            userId,
            provider: result.providerId,
            licenceNumber: kyc.licenceNumber,
          },
        );

        return {
          verified: true,
          status: KycStatus.VERIFIED,
          providerId: result.providerId,
          kyc: updated,
        };
      } else {
        const reason =
          result.data?.rejectionReason ||
          result.error?.message ||
          'Driving licence verification rejected by identity registry';

        // Only mark REJECTED if verification explicitly completed and reported invalid
        if (result.success && result.data && result.data.isValid === false) {
          const updated = await this.prisma.customerKyc.update({
            where: { userId },
            data: {
              status: KycStatus.REJECTED,
              rejectionReason: reason,
            },
          });

          await this.auditLogService.log(
            'system',
            'KYC_REJECTED_AUTOMATED',
            'CustomerKyc',
            kyc.id,
            {
              userId,
              provider: result.providerId,
              reason,
            },
          );

          return {
            verified: false,
            status: KycStatus.REJECTED,
            rejectionReason: reason,
            providerId: result.providerId,
            kyc: updated,
          };
        }

        // Otherwise (provider unconfigured/unavailable), leave in PENDING for manual admin review
        return {
          verified: false,
          status: kyc.status,
          message: `Automated provider check skipped (${result.error?.message || 'pending review'}). Retained in manual queue.`,
          kyc,
        };
      }
    } catch (err: any) {
      this.logger.error(`Automated KYC verification encountered error: ${err.message}`);
      return {
        verified: false,
        status: kyc.status,
        message: `Automated verification error: ${err.message}. Submitted for manual admin review.`,
        kyc,
      };
    }
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

    let frontUrl = kyc.licenceFrontUrl;
    let backUrl = kyc.licenceBackUrl;
    if (this.uploadsService) {
      frontUrl = await this.uploadsService.getPresignedDownloadUrl(kyc.licenceFrontUrl);
      backUrl = await this.uploadsService.getPresignedDownloadUrl(kyc.licenceBackUrl);
    }

    return {
      status: kyc.status,
      kyc: {
        ...kyc,
        licenceFrontUrl: frontUrl,
        licenceBackUrl: backUrl,
      },
    };
  }

  /**
   * Admin: List pending KYC submissions for review
   */
  async getPendingKycSubmissions() {
    const submissions = await this.prisma.customerKyc.findMany({
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

    if (!this.uploadsService) {
      return submissions;
    }

    return Promise.all(
      submissions.map(async (k) => ({
        ...k,
        licenceFrontUrl: await this.uploadsService!.getPresignedDownloadUrl(k.licenceFrontUrl),
        licenceBackUrl: await this.uploadsService!.getPresignedDownloadUrl(k.licenceBackUrl),
      })),
    );
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
