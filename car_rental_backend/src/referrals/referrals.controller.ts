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
    const userId = req.user.id || req.user.userId;
    return this.referralsService.getOrCreateUserReferralCode(userId);
  }

  /**
   * Get current user's referral earnings and invited list.
   */
  @Get('history')
  async getMyReferralHistory(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.getReferralHistory(userId);
  }

  /**
   * Check if current user is eligible for first-booking referral discount.
   */
  @Get('eligibility')
  async getRefereeEligibility(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.getRefereeEligibility(userId);
  }

  /**
   * Apply someone's referral code to current user's account.
   */
  @Post('apply-code')
  async applyReferralCode(
    @Req() req: any,
    @Body() dto: ApplyReferralCodeDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.applyReferralCode(userId, dto);
  }
}
