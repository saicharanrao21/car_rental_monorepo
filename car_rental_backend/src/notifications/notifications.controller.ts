import { Controller, Get, Post, Patch, Body, Query, UseGuards, Req, ParseIntPipe } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { NotificationsService } from './notifications.service';
import { SendBulkDto } from './dto/send-bulk.dto';
import { PaginationDto } from '../common/pagination.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('admin/notifications/send')
  @Roles(Role.ADMIN)
  async sendBulk(@Body() dto: SendBulkDto) {
    return this.notificationsService.sendBulk(dto);
  }

  @Get('admin/notifications/history')
  @Roles(Role.ADMIN)
  async getHistory(
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.notificationsService.getHistory(page ?? 1, limit ?? 10);
  }

  @Get('notifications/me')
  async getMyNotifications(
    @Req() req: any,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.notificationsService.getMyNotifications(req.user.userId, page ?? 1, limit ?? 10);
  }

  @Patch('notifications/me/mark-all-read')
  async markAllRead(@Req() req: any) {
    return this.notificationsService.markAllRead(req.user.userId);
  }
}
