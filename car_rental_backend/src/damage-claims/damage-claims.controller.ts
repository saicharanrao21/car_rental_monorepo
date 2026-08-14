import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { DamageClaimsService } from './damage-claims.service';
import { CreateDamageClaimDto } from './dto/create-damage-claim.dto';
import { AdjudicateClaimDto } from './dto/adjudicate-claim.dto';
import { DisputeClaimDto } from './dto/dispute-claim.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class DamageClaimsController {
  constructor(private readonly damageClaimsService: DamageClaimsService) {}

  @Post('bookings/:id/damage-claims')
  @Roles(Role.VENDOR, Role.ADMIN)
  async createClaim(
    @Param('id') bookingId: string,
    @Body() dto: CreateDamageClaimDto,
    @Request() req: any,
  ) {
    return this.damageClaimsService.createClaim(bookingId, dto, req.user);
  }

  @Get('bookings/:id/damage-claims')
  async getClaimsForBooking(@Param('id') bookingId: string, @Request() req: any) {
    return this.damageClaimsService.getClaimsForBooking(bookingId, req.user);
  }

  @Post('damage-claims/:id/dispute')
  @Roles(Role.CUSTOMER)
  async disputeClaim(
    @Param('id') claimId: string,
    @Body() dto: DisputeClaimDto,
    @Request() req: any,
  ) {
    return this.damageClaimsService.disputeClaim(claimId, dto, req.user);
  }

  @Patch('admin/damage-claims/:id/adjudicate')
  @Roles(Role.ADMIN)
  async adjudicateClaim(
    @Param('id') claimId: string,
    @Body() dto: AdjudicateClaimDto,
    @Request() req: any,
  ) {
    return this.damageClaimsService.adjudicateClaim(claimId, dto, req.user.userId);
  }
}
