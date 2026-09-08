import {
  Controller,
  Get,
  Post,
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
import { Roles } from '../../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { VendorsService } from '../vendors.service';
import { VendorOnboardingEligibilityService } from './vendor-onboarding-eligibility.service';
import { VendorOnboardingRequirementsService } from './vendor-onboarding-requirements.service';
import { VendorSecurityDepositService } from './vendor-security-deposit.service';
import {
  SubmitRequirementDto,
  RecordDepositPaymentDto,
} from './onboarding.types';

@Controller('vendors/me/onboarding')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.VENDOR)
export class VendorOnboardingController {
  constructor(
    private readonly vendorsService: VendorsService,
    private readonly eligibilityService: VendorOnboardingEligibilityService,
    private readonly requirementsService: VendorOnboardingRequirementsService,
    private readonly depositService: VendorSecurityDepositService,
  ) {}

  private async getVendorId(req: any): Promise<string> {
    const vendor = await this.vendorsService.findByUserId(req.user.userId);
    return vendor.id;
  }

  @Get('eligibility')
  async getEligibility(
    @Req() req: any,
    @Query('bypassCache') bypassCache?: string,
  ) {
    const vendorId = await this.getVendorId(req);
    return this.eligibilityService.evaluateEligibility(
      vendorId,
      bypassCache === 'true',
    );
  }

  @Get('requirements')
  async getRequirements(@Req() req: any) {
    const vendorId = await this.getVendorId(req);
    return this.requirementsService.resolveRequirementsForVendor(vendorId);
  }

  @Post('requirements/:id/submit')
  @HttpCode(HttpStatus.OK)
  async submitRequirement(
    @Req() req: any,
    @Param('id') requirementDefinitionId: string,
    @Body() dto: SubmitRequirementDto,
  ) {
    const vendorId = await this.getVendorId(req);
    return this.requirementsService.submitRequirement(
      vendorId,
      requirementDefinitionId,
      dto,
      req.user.userId,
    );
  }

  @Get('deposit')
  async getDeposit(@Req() req: any) {
    const vendorId = await this.getVendorId(req);
    return this.depositService.getDepositSummary(vendorId);
  }

  @Post('deposit/payment')
  @HttpCode(HttpStatus.CREATED)
  async recordDepositPayment(
    @Req() req: any,
    @Body() dto: RecordDepositPaymentDto,
  ) {
    const vendorId = await this.getVendorId(req);
    return this.depositService.recordPayment(
      vendorId,
      dto,
      req.user.userId,
      'VENDOR',
    );
  }

  @Get('deposit/ledger')
  async getDepositLedger(@Req() req: any) {
    const vendorId = await this.getVendorId(req);
    return this.depositService.getLedgerEntries(vendorId);
  }
}
