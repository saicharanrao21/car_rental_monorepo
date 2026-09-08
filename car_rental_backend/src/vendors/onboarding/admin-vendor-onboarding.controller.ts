import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { PermissionsGuard } from '../../auth/guards/permissions.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { RequirePermissions } from '../../auth/decorators/permissions.decorator';
import { AdminPermission } from '../../auth/permissions.enum';
import { Role } from '@prisma/client';
import { VendorOnboardingEligibilityService } from './vendor-onboarding-eligibility.service';
import { VendorOnboardingRequirementsService } from './vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from './vendor-security-deposit.service';
import {
  RequirementCategory,
  RequirementScope,
  VendorDepositStatus,
  CreateRequirementDefinitionDto,
  UpdateRequirementDefinitionDto,
  ReviewRequirementDto,
  WaiveRequirementDto,
  RecordDepositPaymentDto,
  AdjustDepositDto,
  HoldDepositDto,
  ReleaseDepositDto,
  RefundDepositDto,
  ForfeitDepositDto,
} from './onboarding.types';

@Controller('admin/vendors')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
@Roles(Role.ADMIN, Role.SUPPORT_AGENT)
export class AdminVendorOnboardingController {
  constructor(
    private readonly eligibilityService: VendorOnboardingEligibilityService,
    private readonly requirementsService: VendorOnboardingRequirementsService,
    private readonly depositService: VendorSecurityDepositService,
  ) {}

  // ==========================================
  // REQUIREMENT DEFINITIONS MANAGEMENT (CRUD)
  // ==========================================

  @Get('requirements/definitions')
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_READ)
  async getDefinitions(
    @Query('category') category?: RequirementCategory,
    @Query('isActive') isActive?: string,
    @Query('scope') scope?: RequirementScope,
  ) {
    return this.requirementsService.findAllDefinitions({
      category,
      isActive: isActive !== undefined ? isActive === 'true' : undefined,
      scope,
    });
  }

  @Get('requirements/definitions/:id')
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_READ)
  async getDefinitionById(@Param('id') id: string) {
    return this.requirementsService.findDefinitionById(id);
  }

  @Post('requirements/definitions')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_WRITE)
  @HttpCode(HttpStatus.CREATED)
  async createDefinition(
    @Req() req: any,
    @Body() dto: CreateRequirementDefinitionDto,
  ) {
    return this.requirementsService.createDefinition(dto, req.user?.userId);
  }

  @Put('requirements/definitions/:id')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_WRITE)
  async updateDefinition(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateRequirementDefinitionDto,
  ) {
    return this.requirementsService.updateDefinition(id, dto, req.user?.userId);
  }

  @Post('requirements/definitions/seed')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_WRITE)
  @HttpCode(HttpStatus.OK)
  async seedDefinitions() {
    await this.requirementsService.seedDefaultRequirementDefinitions();
    return { success: true, message: 'Default onboarding requirements verified/seeded.' };
  }

  // ==========================================
  // VERIFICATION REVIEW QUEUE (TAB 3)
  // ==========================================

  @Get('onboarding/pending-verifications')
  @RequirePermissions(AdminPermission.VENDOR_VERIFICATION_READ)
  async getPendingVerifications(
    @Query('category') category?: RequirementCategory,
    @Query('vendorId') vendorId?: string,
  ) {
    return this.requirementsService.getPendingVerifications({
      category,
      vendorId,
    });
  }

  // ==========================================
  // DEPOSITS OVERVIEW & SEARCH (TAB 2)
  // ==========================================

  @Get('deposits')
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_READ)
  async listDeposits(
    @Query('status') status?: VendorDepositStatus,
    @Query('search') search?: string,
  ) {
    return this.depositService.listDeposits({ status, search });
  }

  // ==========================================
  // INDIVIDUAL VENDOR ONBOARDING & AUDIT REVIEWS
  // ==========================================

  @Get(':id/onboarding/eligibility')
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_READ)
  async getVendorEligibility(
    @Param('id') vendorId: string,
    @Query('bypassCache') bypassCache?: string,
  ) {
    return this.eligibilityService.evaluateEligibility(
      vendorId,
      bypassCache === 'true',
    );
  }

  @Get(':id/onboarding/requirements')
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_READ)
  async getVendorRequirements(@Param('id') vendorId: string) {
    return this.requirementsService.resolveRequirementsForVendor(vendorId);
  }

  @Post(':id/onboarding/requirements/:reqId/review')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_VERIFICATION_WRITE)
  @HttpCode(HttpStatus.OK)
  async reviewRequirement(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Param('reqId') requirementDefinitionId: string,
    @Body() dto: ReviewRequirementDto,
  ) {
    return this.requirementsService.reviewRequirement(
      vendorId,
      requirementDefinitionId,
      dto,
      req.user?.userId,
    );
  }

  @Post(':id/onboarding/requirements/:reqId/waive')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_REQUIREMENTS_WRITE)
  @HttpCode(HttpStatus.OK)
  async waiveRequirement(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Param('reqId') requirementDefinitionId: string,
    @Body() dto: WaiveRequirementDto,
  ) {
    return this.requirementsService.waiveRequirement(
      vendorId,
      requirementDefinitionId,
      dto,
      req.user?.userId,
    );
  }

  // ==========================================
  // VENDOR SECURITY DEPOSIT MANAGEMENT
  // ==========================================

  @Get(':id/deposit')
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_READ)
  async getDeposit(@Param('id') vendorId: string) {
    return this.depositService.getDeposit(vendorId);
  }

  @Post(':id/deposit/record-payment')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.CREATED)
  async recordDepositPayment(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto: RecordDepositPaymentDto,
  ) {
    return this.depositService.recordPayment(
      vendorId,
      dto,
      req.user?.userId,
      'ADMIN',
    );
  }

  @Post(':id/deposit/adjust')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.OK)
  async adjustDeposit(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto: AdjustDepositDto,
  ) {
    return this.depositService.adjustDeposit(vendorId, dto, req.user?.userId);
  }

  @Post(':id/deposit/hold')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.OK)
  async holdDeposit(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto?: HoldDepositDto,
  ) {
    return this.depositService.holdDeposit(vendorId, req.user?.userId, dto?.reason);
  }

  @Post(':id/deposit/release')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.OK)
  async releaseDeposit(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto: ReleaseDepositDto,
  ) {
    return this.depositService.releaseDeposit(vendorId, dto, req.user?.userId);
  }

  @Post(':id/deposit/refund')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.OK)
  async refundDeposit(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto: RefundDepositDto,
  ) {
    return this.depositService.refundDeposit(vendorId, dto, req.user?.userId);
  }

  @Post(':id/deposit/forfeit')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_WRITE)
  @HttpCode(HttpStatus.OK)
  async forfeitDeposit(
    @Req() req: any,
    @Param('id') vendorId: string,
    @Body() dto: ForfeitDepositDto,
  ) {
    return this.depositService.forfeitDeposit(vendorId, dto, req.user?.userId);
  }

  @Get(':id/deposit/ledger')
  @RequirePermissions(AdminPermission.VENDOR_DEPOSIT_READ)
  async getDepositLedger(@Param('id') vendorId: string) {
    return this.depositService.getLedgerEntries(vendorId);
  }
}
