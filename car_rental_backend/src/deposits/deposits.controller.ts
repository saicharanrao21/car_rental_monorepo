import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { DepositsService } from './deposits.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class DepositsController {
  constructor(private readonly depositsService: DepositsService) {}

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
}
