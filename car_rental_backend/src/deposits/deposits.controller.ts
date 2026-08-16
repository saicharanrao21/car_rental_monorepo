import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { DepositsService } from './deposits.service';
import { DepositRulesService } from './deposit-rules.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, CarCategory } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class DepositsController {
  constructor(
    private readonly depositsService: DepositsService,
    private readonly depositRulesService: DepositRulesService,
  ) {}

  @Get('bookings/:id/deposit')
  async getDeposit(@Param('id') bookingId: string, @Request() req: any) {
    return this.depositsService.getDeposit(bookingId, req.user);
  }

  @Post('bookings/:id/deposit/release')
  @Roles(Role.ADMIN)
  async releaseDeposit(
    @Param('id') bookingId: string,
    @Body('reason') reason: string,
    @Request() req: any,
  ) {
    return this.depositsService.releaseDeposit(bookingId, req.user.userId, reason);
  }

  @Get('admin/deposit-rules')
  @Roles(Role.ADMIN)
  async getAllDepositRules() {
    return this.depositRulesService.getAllRules();
  }

  @Post('admin/deposit-rules')
  @Roles(Role.ADMIN)
  async upsertDepositRule(
    @Body('carCategory') carCategory: CarCategory,
    @Body('depositAmount') depositAmount: number,
    @Body('city') city?: string,
  ) {
    return this.depositRulesService.upsertRule(carCategory, depositAmount, city);
  }

  @Delete('admin/deposit-rules/:id')
  @Roles(Role.ADMIN)
  async deleteDepositRule(@Param('id') id: string) {
    return this.depositRulesService.deleteRule(id);
  }
}

