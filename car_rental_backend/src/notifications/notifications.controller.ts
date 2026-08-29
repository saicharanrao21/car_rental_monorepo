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
  ParseBoolPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';
import { NotificationsService } from './notifications.service';
import { SendBulkDto } from './dto/send-bulk.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  // ── Admin Broadcasts ──────────────────────────────────────────────────────

  @Post('admin/notifications/send')
  @RequirePermissions(AdminPermission.BANNER_MANAGE)
  async sendBulk(@Req() req: any, @Body() dto: SendBulkDto) {
    const adminUserId = req.user.id || req.user.userId;
    return this.notificationsService.sendBulk(dto, adminUserId);
  }

  @Get('admin/notifications/history')
  @Roles(Role.ADMIN)
  async getHistory(
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.notificationsService.getHistory(page ?? 1, limit ?? 10);
  }

  // ── Device Token Registration ─────────────────────────────────────────────

  @Post('notifications/devices/register')
  async registerDevice(@Req() req: any, @Body() dto: RegisterDeviceDto) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.registerDevice(userId, dto);
  }

  @Post('notifications/devices/unregister')
  async unregisterDevice(@Req() req: any, @Body('token') token: string) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.unregisterDevice(userId, token);
  }

  // ── Notification Preferences ──────────────────────────────────────────────

  @Get('notifications/preferences')
  async getPreferences(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.getPreferences(userId);
  }

  @Patch('notifications/preferences')
  async updatePreferences(
    @Req() req: any,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.updatePreferences(userId, dto);
  }

  // ── Customer & Vendor Notification Center ─────────────────────────────────

  @Get('notifications/me')
  async getMyNotifications(
    @Req() req: any,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
    @Query('unreadOnly', new ParseBoolPipe({ optional: true }))
    unreadOnly?: boolean,
    @Query('category') category?: string,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.getMyNotifications(
      userId,
      page ?? 1,
      limit ?? 20,
      unreadOnly ?? false,
      category,
    );
  }

  @Get('notifications/me/unread-count')
  async getUnreadCount(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    const count = await this.notificationsService.getUnreadCount(userId);
    return { unreadCount: count };
  }

  @Patch('notifications/:id/read')
  async markAsRead(@Req() req: any, @Param('id') id: string) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.markAsRead(userId, id);
  }

  @Patch('notifications/me/mark-all-read')
  async markAllRead(@Req() req: any) {
    const userId = req.user.id || req.user.userId;
    return this.notificationsService.markAllAsRead(userId);
  }
}
