import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisCacheService } from '../../redis/redis-cache.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../../redis/redis-namespace.constants';
import { AuditLogService } from '../../admin/audit-log.service';
import { SystemConfigService } from '../../config-engine/system-config.service';
import {
  RequirementCategory,
  RequirementScope,
  RequirementFulfillmentStatus,
  CreateRequirementDefinitionDto,
  UpdateRequirementDefinitionDto,
  SubmitRequirementDto,
  ReviewRequirementDto,
  WaiveRequirementDto,
  VendorRequirementItem,
} from './onboarding.types';

@Injectable()
export class VendorOnboardingRequirementsService {
  private readonly logger = new Logger(VendorOnboardingRequirementsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cacheService: RedisCacheService,
    @Optional() private readonly auditLogService?: AuditLogService,
    @Optional() private readonly systemConfigService?: SystemConfigService,
  ) {}

  /**
   * Seeds default standard onboarding requirements if none exist.
   */
  async seedDefaultRequirementDefinitions(): Promise<any[]> {
    const count = await this.prisma.onboardingRequirementDefinition.count();
    if (count > 0) return this.findAllDefinitions();

    const defaults = [
      {
        code: 'DOC_PAN',
        name: 'PAN Card',
        description: 'Permanent Account Number of Business or Proprietor',
        category: RequirementCategory.DOCUMENT,
        isRequired: true,
        isActive: true,
        displayOrder: 1,
        scope: RequirementScope.GLOBAL,
        version: 1,
        config: { acceptableFormats: ['pdf', 'jpg', 'png'], requiresExpiry: false },
      },
      {
        code: 'DOC_GST',
        name: 'GST Certificate',
        description: 'Goods and Services Tax Registration Certificate',
        category: RequirementCategory.DOCUMENT,
        isRequired: true,
        isActive: true,
        displayOrder: 2,
        scope: RequirementScope.GLOBAL,
        version: 1,
        config: { acceptableFormats: ['pdf', 'jpg', 'png'], requiresExpiry: false },
      },
      {
        code: 'DOC_TRADE_LICENSE',
        name: 'Trade / Business License',
        description: 'Municipal trade license or shops and establishment permit',
        category: RequirementCategory.DOCUMENT,
        isRequired: true,
        isActive: true,
        displayOrder: 3,
        scope: RequirementScope.GLOBAL,
        version: 1,
        config: { acceptableFormats: ['pdf', 'jpg', 'png'], requiresExpiry: true },
      },
      {
        code: 'DEP_SECURITY',
        name: 'Platform Security Deposit',
        description: 'Refundable partner security deposit for platform operations',
        category: RequirementCategory.MONETARY,
        isRequired: true,
        isActive: true,
        displayOrder: 4,
        scope: RequirementScope.GLOBAL,
        version: 1,
        config: { amount: 25000, currency: 'INR', allowPartial: true, minInitialPercentage: 20 },
      },
      {
        code: 'ASSET_PARKING_PROOF',
        name: 'Fleet Yard & Parking Proof',
        description: 'Physical lease agreement or ownership document for vehicle parking hub',
        category: RequirementCategory.PHYSICAL_ASSET,
        isRequired: true,
        isActive: true,
        displayOrder: 5,
        scope: RequirementScope.GLOBAL,
        version: 1,
        config: { requiredPhotos: ['GATE', 'PARKING_BAY'], geoTagRequired: true },
      },
    ];

    for (const def of defaults) {
      await this.prisma.onboardingRequirementDefinition.create({ data: def });
    }
    this.logger.log('Seeded standard default onboarding requirement definitions');
    return this.findAllDefinitions();
  }

  /**
   * Retrieves all requirement definitions with optional category / active filtering.
   */
  async findAllDefinitions(filter?: {
    category?: RequirementCategory;
    isActive?: boolean;
    scope?: RequirementScope;
  }) {
    const where: any = {};
    if (filter?.category) where.category = filter.category;
    if (filter?.isActive !== undefined) where.isActive = filter.isActive;
    if (filter?.scope) where.scope = filter.scope;

    return this.prisma.onboardingRequirementDefinition.findMany({
      where,
      orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  /**
   * Retrieves a single requirement definition by ID.
   */
  async findDefinitionById(id: string) {
    const def = await this.prisma.onboardingRequirementDefinition.findUnique({
      where: { id },
    });
    if (!def) {
      throw new NotFoundException(`Onboarding requirement definition [${id}] not found.`);
    }
    return def;
  }

  /**
   * Creates a new requirement definition.
   */
  async createDefinition(dto: CreateRequirementDefinitionDto, adminUserId?: string) {
    // Check if code exists for active version
    const existing = await this.prisma.onboardingRequirementDefinition.findFirst({
      where: { code: dto.code },
      orderBy: { version: 'desc' },
    });

    const version = existing ? existing.version + 1 : 1;

    const created = await this.prisma.onboardingRequirementDefinition.create({
      data: {
        code: dto.code,
        name: dto.name || (dto as any).title,
        description: dto.description,
        category: dto.category,
        isRequired: dto.isRequired ?? true,
        isActive: dto.isActive ?? true,
        displayOrder: dto.displayOrder ?? 0,
        scope: dto.scope ?? RequirementScope.GLOBAL,
        targetScopeValue:
          dto.targetScopeValue ??
          (dto as any).applicableServiceAreaId ??
          (dto as any).applicableCategory,
        version,
        effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : new Date(),
        effectiveTo: dto.effectiveTo ? new Date(dto.effectiveTo) : null,
        config: dto.config ? dto.config : undefined,
      },
    });

    if (adminUserId && this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'CREATE_ONBOARDING_REQUIREMENT',
        'ONBOARDING_REQUIREMENT',
        created.id,
        { code: created.code, version: created.version },
      );
    }

    await this.cacheService.delete(REDIS_NAMESPACES.CACHE.ONBOARDING_REQUIREMENTS_ALL());
    return created;
  }

  /**
   * Updates an existing requirement definition, supporting optional non-destructive versioning.
   */
  async updateDefinition(
    id: string,
    dto: UpdateRequirementDefinitionDto,
    adminUserId?: string,
  ) {
    const current = await this.findDefinitionById(id);

    if (dto.createNewVersion) {
      // Archive current version
      await this.prisma.onboardingRequirementDefinition.update({
        where: { id: current.id },
        data: {
          effectiveTo: new Date(),
          isActive: false,
        },
      });

      // Create new incremented version
      const newVersion = await this.prisma.onboardingRequirementDefinition.create({
        data: {
          code: current.code,
          name: dto.name ?? current.name,
          description: dto.description ?? current.description,
          category: current.category,
          isRequired: dto.isRequired ?? current.isRequired,
          isActive: dto.isActive ?? true,
          displayOrder: dto.displayOrder ?? current.displayOrder,
          scope: dto.scope ?? current.scope,
          targetScopeValue: dto.targetScopeValue ?? current.targetScopeValue,
          version: current.version + 1,
          effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : new Date(),
          effectiveTo: dto.effectiveTo ? new Date(dto.effectiveTo) : null,
          config: dto.config ?? (current.config as any),
        },
      });

      if (adminUserId && this.auditLogService) {
        await this.auditLogService.log(
          adminUserId,
          'VERSION_ONBOARDING_REQUIREMENT',
          'ONBOARDING_REQUIREMENT',
          newVersion.id,
          {
            previousId: current.id,
            previousVersion: current.version,
            newVersion: newVersion.version,
            reason: dto.reason,
          },
        );
      }

      await this.cacheService.delete(REDIS_NAMESPACES.CACHE.ONBOARDING_REQUIREMENTS_ALL());
      return newVersion;
    }

    // In-place mutation
    const updated = await this.prisma.onboardingRequirementDefinition.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.isRequired !== undefined && { isRequired: dto.isRequired }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.displayOrder !== undefined && { displayOrder: dto.displayOrder }),
        ...(dto.scope !== undefined && { scope: dto.scope }),
        ...(dto.targetScopeValue !== undefined && { targetScopeValue: dto.targetScopeValue }),
        ...(dto.effectiveFrom !== undefined && { effectiveFrom: new Date(dto.effectiveFrom) }),
        ...(dto.effectiveTo !== undefined && { effectiveTo: dto.effectiveTo ? new Date(dto.effectiveTo) : null }),
        ...(dto.config !== undefined && { config: dto.config }),
      },
    });

    if (adminUserId && this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'UPDATE_ONBOARDING_REQUIREMENT',
        'ONBOARDING_REQUIREMENT',
        updated.id,
        { changes: dto },
      );
    }

    await this.cacheService.delete(REDIS_NAMESPACES.CACHE.ONBOARDING_REQUIREMENTS_ALL());
    return updated;
  }

  /**
   * Resolves applicable requirement definitions for a vendor and returns state instances.
   */
  async resolveRequirementsForVendor(vendorId: string): Promise<VendorRequirementItem[]> {
    // 1. Fetch vendor context
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      include: {
        cars: { select: { type: true } },
        serviceAreaAssignments: { select: { serviceAreaId: true } },
      },
    });

    if (!vendor) {
      throw new NotFoundException(`Vendor [${vendorId}] not found.`);
    }

    // 2. Fetch all active requirement definitions
    const now = new Date();
    const activeDefinitions = await this.prisma.onboardingRequirementDefinition.findMany({
      where: {
        isActive: true,
        effectiveFrom: { lte: now },
        OR: [{ effectiveTo: null }, { effectiveTo: { gt: now } }],
      },
      orderBy: { displayOrder: 'asc' },
    });

    // 3. Filter by scope
    const vendorCategories = new Set(vendor.cars.map((c) => c.type));
    const vendorServiceAreas = new Set(vendor.serviceAreaAssignments.map((a) => a.serviceAreaId));

    const applicableDefs = activeDefinitions.filter((def) => {
      switch (def.scope) {
        case RequirementScope.GLOBAL:
          return true;
        case RequirementScope.VENDOR_SPECIFIC:
          return def.targetScopeValue === vendorId;
        case RequirementScope.VEHICLE_CATEGORY:
          return def.targetScopeValue ? vendorCategories.has(def.targetScopeValue as any) : false;
        case RequirementScope.SERVICE_AREA:
          return def.targetScopeValue ? vendorServiceAreas.has(def.targetScopeValue) : false;
        default:
          return true;
      }
    });

    // 4. Fetch existing states for this vendor
    const existingStates = await this.prisma.vendorRequirementState.findMany({
      where: { vendorId },
    });
    const stateMap = new Map<string, any>(
      existingStates.map((s) => [s.requirementDefinitionId, s]),
    );

    const items: VendorRequirementItem[] = [];

    for (const def of applicableDefs) {
      let state = stateMap.get(def.id);

      if (!state) {
        // Automatically initialize missing requirement state in PENDING
        state = await this.prisma.vendorRequirementState.create({
          data: {
            vendorId,
            requirementDefinitionId: def.id,
            status: RequirementFulfillmentStatus.PENDING,
          },
        });
      }

      // Check document expiry if APPROVED or SUBMITTED
      let effectiveStatus = state.status;
      let isExpired = false;

      if (state.expiresAt && state.expiresAt < now) {
        isExpired = true;
        if (
          effectiveStatus === RequirementFulfillmentStatus.APPROVED ||
          effectiveStatus === RequirementFulfillmentStatus.SUBMITTED
        ) {
          effectiveStatus = RequirementFulfillmentStatus.EXPIRED;
          await this.prisma.vendorRequirementState.update({
            where: { id: state.id },
            data: { status: RequirementFulfillmentStatus.EXPIRED },
          });
        }
      }

      items.push({
        id: state.id,
        requirementDefinitionId: def.id,
        code: def.code,
        name: def.name,
        description: def.description,
        category: def.category,
        isRequired: def.isRequired,
        scope: def.scope,
        status: effectiveStatus,
        documentId: state.documentId,
        documentNumber: state.documentNumber,
        issuedAt: state.issuedAt,
        expiresAt: state.expiresAt,
        isExpired,
        submissionData: state.submissionData,
        submittedAt: state.submittedAt,
        rejectionReason: state.rejectionReason,
        reviewedByUserId: state.reviewedByUserId,
        reviewedAt: state.reviewedAt,
        waivedByUserId: state.waivedByUserId,
        waivedReason: state.waivedReason,
        waiverReason: state.waivedReason,
        waivedAt: state.waivedAt,
        config: def.config,
        definition: def,
      });
    }

    return items;
  }

  /**
   * Submits proof or documents for a requirement.
   */
  async submitRequirement(
    vendorId: string,
    requirementDefinitionId: string,
    dto: SubmitRequirementDto,
    actorId?: string,
  ) {
    const def = await this.findDefinitionById(requirementDefinitionId);

    // Validate scope enforcement
    if (def.scope === RequirementScope.SERVICE_AREA && def.targetScopeValue) {
      const assignment = await this.prisma.vendorServiceArea.findFirst({
        where: {
          vendorId,
          serviceAreaId: def.targetScopeValue,
        },
      });
      if (!assignment) {
        throw new BadRequestException(
          `Vendor [${vendorId}] is not authorized for service area [${def.targetScopeValue}]. Cannot fulfill this requirement.`,
        );
      }
    }

    if (def.scope === RequirementScope.VENDOR_SPECIFIC && def.targetScopeValue && def.targetScopeValue !== vendorId) {
      throw new BadRequestException(
        `This requirement is scoped to vendor [${def.targetScopeValue}], not vendor [${vendorId}].`,
      );
    }

    const status = (dto as any).status || RequirementFulfillmentStatus.SUBMITTED;

    // Upsert requirement state
    const state = await this.prisma.vendorRequirementState.upsert({
      where: {
        vendorId_requirementDefinitionId: {
          vendorId,
          requirementDefinitionId,
        },
      },
      update: {
        documentId: dto.documentId,
        documentNumber: dto.documentNumber,
        issuedAt: dto.issuedAt ? new Date(dto.issuedAt) : undefined,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
        submissionData: dto.submissionData ? dto.submissionData : undefined,
        submittedAt: new Date(),
        status,
        rejectionReason: null, // clear previous rejection on resubmission
      },
      create: {
        vendorId,
        requirementDefinitionId,
        documentId: dto.documentId,
        documentNumber: dto.documentNumber,
        issuedAt: dto.issuedAt ? new Date(dto.issuedAt) : undefined,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
        submissionData: dto.submissionData ? dto.submissionData : undefined,
        submittedAt: new Date(),
        status,
      },
    });

    await this.invalidateVendorCache(vendorId);

    if (actorId && this.auditLogService) {
      await this.auditLogService.log(
        actorId,
        'SUBMIT_ONBOARDING_REQUIREMENT',
        'VENDOR_REQUIREMENT',
        state.id,
        { vendorId, code: def.code },
      );
    }

    return state;
  }

  /**
   * Convenience method to submit document fulfillment.
   */
  async submitDocumentFulfillment(
    vendorId: string,
    dto: {
      requirementDefinitionId: string;
      fileUrl?: string;
      documentType?: any;
      documentId?: string;
      documentNumber?: string;
      expiresAt?: string;
      status?: RequirementFulfillmentStatus;
    },
    actorId?: string,
  ) {
    return this.submitRequirement(
      vendorId,
      dto.requirementDefinitionId,
      {
        documentId: dto.documentId || dto.fileUrl || 'doc-1',
        documentNumber: dto.documentNumber,
        expiresAt: dto.expiresAt,
        submissionData: { fileUrl: dto.fileUrl, documentType: dto.documentType },
        status: dto.status ?? RequirementFulfillmentStatus.SUBMITTED,
      } as any,
      actorId,
    );
  }

  /**
   * Reviews (Approves or Rejects) a requirement submission.
   */
  async reviewRequirement(
    vendorId: string,
    requirementDefinitionId: string,
    dto: ReviewRequirementDto,
    adminUserId: string,
  ) {
    const status = dto.status || (dto as any).decision;
    const rejectionReason = dto.rejectionReason || (dto as any).reviewNotes;

    if (
      status === RequirementFulfillmentStatus.REJECTED &&
      (!rejectionReason || rejectionReason.trim().length === 0)
    ) {
      throw new BadRequestException('Rejection reason is mandatory when rejecting a requirement.');
    }

    const state = await this.prisma.vendorRequirementState.findUnique({
      where: {
        vendorId_requirementDefinitionId: {
          vendorId,
          requirementDefinitionId,
        },
      },
    });

    if (!state) {
      throw new NotFoundException(
        `Requirement state for definition [${requirementDefinitionId}] and vendor [${vendorId}] not found.`,
      );
    }

    const updated = await this.prisma.vendorRequirementState.update({
      where: { id: state.id },
      data: {
        status,
        rejectionReason: status === RequirementFulfillmentStatus.REJECTED ? rejectionReason : null,
        reviewedByUserId: adminUserId,
        reviewedAt: new Date(),
        ...(dto.expiresAt && { expiresAt: new Date(dto.expiresAt) }),
      },
    });

    await this.invalidateVendorCache(vendorId);

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        `REVIEW_REQUIREMENT_${status}`,
        'VENDOR_REQUIREMENT',
        updated.id,
        { vendorId, status, rejectionReason },
      );
    }

    return {
      ...updated,
      verifiedAt: updated.reviewedAt,
      verifiedBy: updated.reviewedByUserId,
      rejectionReason: updated.rejectionReason,
    };
  }

  /**
   * Waives a requirement with a mandatory audit reason.
   */
  async waiveRequirement(
    vendorId: string,
    requirementDefinitionId: string,
    dto: WaiveRequirementDto,
    adminUserId: string,
  ) {
    if (!dto.reason || dto.reason.trim().length === 0) {
      throw new BadRequestException('A valid reason is required to waive an onboarding requirement.');
    }

    const state = await this.prisma.vendorRequirementState.upsert({
      where: {
        vendorId_requirementDefinitionId: {
          vendorId,
          requirementDefinitionId,
        },
      },
      update: {
        status: RequirementFulfillmentStatus.WAIVED,
        waivedByUserId: adminUserId,
        waivedReason: dto.reason,
        waivedAt: new Date(),
      },
      create: {
        vendorId,
        requirementDefinitionId,
        status: RequirementFulfillmentStatus.WAIVED,
        waivedByUserId: adminUserId,
        waivedReason: dto.reason,
        waivedAt: new Date(),
      },
    });

    await this.invalidateVendorCache(vendorId);

    if (this.auditLogService) {
      await this.auditLogService.log(
        adminUserId,
        'WAIVE_ONBOARDING_REQUIREMENT',
        'VENDOR_REQUIREMENT',
        state.id,
        { vendorId, requirementDefinitionId, reason: dto.reason },
      );
    }

    return {
      ...state,
      waiverReason: state.waivedReason,
    };
  }

  /**
   * Retrieves pending verification submissions across vendors for the admin review queue.
   */
  async getPendingVerifications(filter?: {
    category?: RequirementCategory;
    vendorId?: string;
  }) {
    const where: any = {
      status: {
        in: [RequirementFulfillmentStatus.SUBMITTED, RequirementFulfillmentStatus.UNDER_REVIEW],
      },
    };

    if (filter?.vendorId) {
      where.vendorId = filter.vendorId;
    }

    if (filter?.category) {
      where.requirementDefinition = { category: filter.category };
    }

    return this.prisma.vendorRequirementState.findMany({
      where,
      include: {
        vendor: {
          select: {
            id: true,
            businessName: true,
            verificationStatus: true,
            user: { select: { name: true, email: true, phone: true } },
          },
        },
        requirementDefinition: true,
      },
      orderBy: [{ submittedAt: 'asc' }, { updatedAt: 'desc' }],
    });
  }

  /**
   * Invalidates Redis caches associated with vendor onboarding.
   */
  async invalidateVendorCache(vendorId: string): Promise<void> {
    await Promise.all([
      this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_REQUIREMENTS(vendorId)),
      this.cacheService.delete(REDIS_NAMESPACES.CACHE.VENDOR_ONBOARDING_ELIGIBILITY(vendorId)),
    ]);
  }
}
