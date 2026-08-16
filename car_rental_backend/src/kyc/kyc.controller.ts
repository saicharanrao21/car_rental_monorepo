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
    return this.kycService.submitKyc(req.user.userId, dto);
  }

  @Get('kyc/status')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN)
  async getKycStatus(@Request() req: any) {
    return this.kycService.getKycStatus(req.user.userId);
  }

  @Get('admin/kyc/pending')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getPendingKycSubmissions() {
    return this.kycService.getPendingKycSubmissions();
  }

  @Patch('admin/kyc/:id/review')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async reviewKyc(
    @Request() req: any,
    @Param('id') kycId: string,
    @Body() dto: ReviewKycDto,
  ) {
    return this.kycService.reviewKyc(req.user.userId, kycId, dto);
  }
}
