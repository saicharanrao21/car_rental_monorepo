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
    return this.referralsService.createAdminCampaign(req.user.id, dto);
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
    return this.referralsService.updateAdminCampaign(req.user.id, id, dto);
  }

  /**
   * Toggle active status of a referral campaign.
   */
  @Post('campaigns/:id/toggle')
  async toggleCampaign(
    @Req() req: any,
    @Param('id') id: string,
  ) {
    return this.referralsService.toggleAdminCampaign(req.user.id, id);
  }
}
