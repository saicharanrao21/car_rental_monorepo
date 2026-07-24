import { Controller, Get, Patch, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { DisputesService } from './disputes.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, DisputeStatus } from '@prisma/client';
import { UpdateDisputeDto } from './dto/update-dispute.dto';
import { PaginationDto } from '../common/pagination.dto';

@Controller('admin/disputes')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminDisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Get()
  async adminGetDisputes(
    @Query('status') status?: DisputeStatus,
    @Query() pagination?: PaginationDto,
  ) {
    return this.disputesService.adminGetDisputes(status, pagination);
  }

  @Patch(':id')
  async adminUpdateDispute(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateDisputeDto,
  ) {
    return this.disputesService.adminUpdateDispute(req.user.userId, id, dto);
  }
}
