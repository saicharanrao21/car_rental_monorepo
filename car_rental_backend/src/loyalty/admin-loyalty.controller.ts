import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { LoyaltyTierCode, Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdminAdjustLoyaltyDto } from './dto/admin-adjust-loyalty.dto';
import { LoyaltyService } from './loyalty.service';

@Controller('admin/loyalty')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminLoyaltyController {
  constructor(private readonly loyaltyService: LoyaltyService) {}

  @Get('summary')
  async getSummary() {
    return this.loyaltyService.getAdminLoyaltySummary();
  }

  @Get('accounts')
  async getAccounts(
    @Query('search') search?: string,
    @Query('tierCode') tierCode?: LoyaltyTierCode,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const p = page ? Math.max(1, parseInt(page, 10)) : 1;
    const l = limit ? Math.min(100, Math.max(1, parseInt(limit, 10))) : 20;
    return this.loyaltyService.getAdminLoyaltyAccounts(search, tierCode, p, l);
  }

  @Get('accounts/:userId/transactions')
  async getAccountTransactions(
    @Param('userId') userId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const p = page ? Math.max(1, parseInt(page, 10)) : 1;
    const l = limit ? Math.min(100, Math.max(1, parseInt(limit, 10))) : 20;
    return this.loyaltyService.getLoyaltyTransactions(userId, p, l);
  }

  @Post('adjust')
  async adjustPoints(@Req() req: any, @Body() dto: AdminAdjustLoyaltyDto) {
    return this.loyaltyService.adminAdjustPoints(req.user.id, dto);
  }
}
