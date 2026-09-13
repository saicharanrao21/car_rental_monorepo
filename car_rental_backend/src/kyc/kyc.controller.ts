import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { KycService } from './kyc.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { SubmitKycDto } from './dto/submit-kyc.dto';
import { ReviewKycDto } from './dto/review-kyc.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class KycController {
  constructor(private readonly kycService: KycService) {}

  @Post('kyc/submit')
  @Roles(Role.CUSTOMER)
  async submitKyc(@Request() req: any, @Body() dto: SubmitKycDto) {
    const userId = req.user.id || req.user.userId;
    return this.kycService.submitKyc(userId, dto);
  }

  @Post('kyc/verify-automated')
  @Roles(Role.CUSTOMER)
  async autoVerifyCustomerKyc(@Request() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.kycService.autoVerifyCustomerKyc(userId);
  }

  @Get('kyc/status')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN)
  async getKycStatus(@Request() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.kycService.getKycStatus(userId);
  }

  @Get('admin/kyc/pending')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getPendingKycSubmissions() {
    return this.kycService.getPendingKycSubmissions();
  }

  @Post('admin/kyc/:userId/verify-automated')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async adminAutoVerifyKyc(@Param('userId') userId: string) {
    return this.kycService.autoVerifyCustomerKyc(userId);
  }

  @Patch('admin/kyc/:id/review')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async reviewKyc(
    @Request() req: any,
    @Param('id') kycId: string,
    @Body() dto: ReviewKycDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.kycService.reviewKyc(userId, kycId, dto);
  }
}
