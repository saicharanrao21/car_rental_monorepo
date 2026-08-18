import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { RedeemPointsDto } from './dto/redeem-points.dto';
import { LoyaltyService } from './loyalty.service';

@Controller('loyalty')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LoyaltyController {
  constructor(private readonly loyaltyService: LoyaltyService) {}

  @Get('account')
  async getMyLoyaltyAccount(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.loyaltyService.getLoyaltyAccount(userId);
  }

  @Get('transactions')
  async getMyTransactions(
    @Req() req: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const userId = req.user.id || req.user.userId;
    const p = page ? Math.max(1, parseInt(page, 10)) : 1;
    const l = limit ? Math.min(100, Math.max(1, parseInt(limit, 10))) : 20;
    return this.loyaltyService.getLoyaltyTransactions(userId, p, l);
  }

  @Get('tiers')
  async getTiers() {
    return this.loyaltyService.getLoyaltyTiers();
  }

  @Post('redeem-to-wallet')
  async redeemPoints(@Req() req: any, @Body() dto: RedeemPointsDto) {
    const userId = req.user.id || req.user.userId;
    return this.loyaltyService.redeemPointsToWallet(userId, dto);
  }
}
