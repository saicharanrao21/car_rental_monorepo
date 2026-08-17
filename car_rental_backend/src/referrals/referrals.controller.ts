import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ReferralsService } from './referrals.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { ApplyReferralCodeDto } from './dto/apply-referral-code.dto';

@Controller('referrals')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReferralsController {
  constructor(private readonly referralsService: ReferralsService) {}

  /**
   * Get current user's unique referral code & share link.
   */
  @Get('my-code')
  async getMyReferralCode(@Req() req: any) {
    return this.referralsService.getOrCreateUserReferralCode(req.user.id);
  }

  /**
   * Get current user's referral earnings and invited list.
   */
  @Get('history')
  async getMyReferralHistory(@Req() req: any) {
    return this.referralsService.getReferralHistory(req.user.id);
  }

  /**
   * Check if current user is eligible for first-booking referral discount.
   */
  @Get('eligibility')
  async getRefereeEligibility(@Req() req: any) {
    return this.referralsService.getRefereeEligibility(req.user.id);
  }

  /**
   * Apply someone's referral code to current user's account.
   */
  @Post('apply-code')
  async applyReferralCode(
    @Req() req: any,
    @Body() dto: ApplyReferralCodeDto,
  ) {
    return this.referralsService.applyReferralCode(req.user.id, dto);
  }
}
