import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { GrowthService } from './growth.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';
import { CreatePromotionalCampaignDto } from './dto/create-promotional-campaign.dto';
import { UpdatePromotionalCampaignDto } from './dto/update-promotional-campaign.dto';
import { CreateSponsoredCampaignDto } from './dto/create-sponsored-campaign.dto';
import { CreateFeaturedListingDto } from './dto/create-featured-listing.dto';
import { RecordAttributionDto } from './dto/record-attribution.dto';

@Controller('growth')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
export class GrowthController {
  constructor(private readonly growthService: GrowthService) {}

  // ── Promotional Campaigns (Admin) ─────────────────────────────────────────

  @Get('campaigns')
  @RequirePermissions(AdminPermission.CAMPAIGN_MANAGE)
  async getCampaigns(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.growthService.getPromotionalCampaigns(page, limit);
  }

  @Post('campaigns')
  @RequirePermissions(AdminPermission.CAMPAIGN_MANAGE)
  async createCampaign(
    @Req() req: any,
    @Body() dto: CreatePromotionalCampaignDto,
  ) {
    const adminUserId = req.user.id || req.user.userId;
    return this.growthService.createPromotionalCampaign(adminUserId, dto);
  }

  @Patch('campaigns/:id')
  @RequirePermissions(AdminPermission.CAMPAIGN_MANAGE)
  async updateCampaign(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdatePromotionalCampaignDto,
  ) {
    const adminUserId = req.user.id || req.user.userId;
    return this.growthService.updatePromotionalCampaign(adminUserId, id, dto);
  }

  // ── Sponsored Campaigns (Vendor & Admin) ──────────────────────────────────

  @Get('sponsored/vendor/me')
  @Roles(Role.VENDOR, Role.ADMIN)
  async getMySponsoredCampaigns(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.growthService.getVendorSponsoredCampaigns(userId);
  }

  @Post('sponsored')
  @Roles(Role.VENDOR, Role.ADMIN)
  async createSponsoredCampaign(
    @Req() req: any,
    @Body() dto: CreateSponsoredCampaignDto,
  ) {
    const userId = req.user.id || req.user.userId;
    const isAdmin = req.user.role === Role.ADMIN;
    return this.growthService.createSponsoredCampaign(userId, dto, isAdmin);
  }

  // ── Featured Listings (Public & Admin) ────────────────────────────────────

  @Get('featured')
  async getFeaturedListings(@Query('city') city?: string) {
    return this.growthService.getFeaturedListings(city);
  }

  @Post('featured')
  @RequirePermissions(AdminPermission.CAMPAIGN_MANAGE)
  async createFeaturedListing(
    @Req() req: any,
    @Body() dto: CreateFeaturedListingDto,
  ) {
    const adminUserId = req.user.id || req.user.userId;
    return this.growthService.createFeaturedListing(adminUserId, dto);
  }

  // ── Attribution & Engagement Tracking ─────────────────────────────────────

  @Post('attribution')
  async recordAttribution(@Body() dto: RecordAttributionDto) {
    return this.growthService.recordAttribution(dto);
  }

  @Post('engagement')
  async recordEngagement(
    @Body('type') type: 'IMPRESSION' | 'CLICK',
    @Body('sponsoredCampaignId') sponsoredCampaignId?: string,
  ) {
    await this.growthService.recordEngagementEvent(type, sponsoredCampaignId);
    return { success: true };
  }
}
