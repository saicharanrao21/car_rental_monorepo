import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ReferralsService } from './referrals.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CreateReferralCampaignDto } from './dto/create-referral-campaign.dto';
import { UpdateReferralCampaignDto } from './dto/update-referral-campaign.dto';

@Controller('admin/referrals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminReferralsController {
  constructor(private readonly referralsService: ReferralsService) {}

  /**
   * List all referral campaigns with performance metrics.
   */
  @Get('campaigns')
  async getCampaigns() {
    return this.referralsService.getAdminCampaigns();
  }

  /**
   * Create a new referral campaign.
   */
  @Post('campaigns')
  async createCampaign(
    @Req() req: any,
    @Body() dto: CreateReferralCampaignDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.createAdminCampaign(userId, dto);
  }

  /**
   * Update an existing referral campaign.
   */
  @Patch('campaigns/:id')
  async updateCampaign(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateReferralCampaignDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.updateAdminCampaign(userId, id, dto);
  }

  /**
   * Toggle active status of a referral campaign.
   */
  @Post('campaigns/:id/toggle')
  async toggleCampaign(
    @Req() req: any,
    @Param('id') id: string,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.referralsService.toggleAdminCampaign(userId, id);
  }
}
