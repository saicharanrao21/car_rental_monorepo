import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { WaitlistService, JoinWaitlistDto } from './waitlist.service';

@Controller('waitlist')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WaitlistController {
  constructor(private readonly waitlistService: WaitlistService) {}

  @Post()
  async joinWaitlist(@Request() req: any, @Body() dto: JoinWaitlistDto) {
    const customerId = req.user.userId || req.user.id;
    return this.waitlistService.joinWaitlist(customerId, dto);
  }

  @Get('my')
  async getMyWaitlist(@Request() req: any) {
    const customerId = req.user.userId || req.user.id;
    return this.waitlistService.getUserWaitlist(customerId);
  }

  @Patch(':id/cancel')
  async cancelWaitlistEntry(@Request() req: any, @Param('id') entryId: string) {
    const customerId = req.user.userId || req.user.id;
    return this.waitlistService.cancelWaitlistEntry(entryId, customerId);
  }

  @Get('admin')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async listWaitlistAdmin(
    @Query('city') city?: string,
    @Query('status') status?: string,
  ) {
    return this.waitlistService.listWaitlistAdmin(city, status);
  }

  @Patch(':id/notify')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async notifyWaitlistEntry(@Param('id') entryId: string) {
    return this.waitlistService.notifyWaitlistEntry(entryId);
  }
}
