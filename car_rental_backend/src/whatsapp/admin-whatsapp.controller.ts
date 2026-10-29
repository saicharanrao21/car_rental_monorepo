import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  UseGuards,
  Request,
  Body,
} from '@nestjs/common';
import { WhatsAppService } from './whatsapp.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import {
  Role,
  WhatsAppMessageStatus,
  WhatsAppMessageType,
} from '@prisma/client';

@Controller('admin/whatsapp')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
@Roles(Role.ADMIN)
export class AdminWhatsAppController {
  constructor(private readonly whatsappService: WhatsAppService) {}

  @Get('summary')
  @RequirePermissions(AdminPermission.ANALYTICS_READ)
  async getSummary() {
    return this.whatsappService.getSummary();
  }

  @Get('messages')
  @RequirePermissions(AdminPermission.SUPPORT_TICKET_READ)
  async getMessages(
    @Query('status') status?: WhatsAppMessageStatus,
    @Query('messageType') messageType?: WhatsAppMessageType,
    @Query('search') search?: string,
    @Query('skip') skip?: number,
    @Query('take') take?: number,
  ) {
    return this.whatsappService.getMessages({
      status,
      messageType,
      search,
      skip: skip ? Number(skip) : 0,
      take: take ? Number(take) : 50,
    });
  }

  @Post('resend/:id')
  @RequirePermissions(AdminPermission.SUPPORT_TICKET_WRITE)
  async resendMessage(@Param('id') id: string, @Request() req: any) {
    const adminUserId = req.user?.userId || req.user?.id || 'admin';
    return this.whatsappService.resendMessage(id, adminUserId);
  }

  @Get('templates')
  @RequirePermissions(AdminPermission.SUPPORT_TICKET_READ)
  async getTemplates() {
    return this.whatsappService.getRegisteredTemplates();
  }

  @Post('send')
  @RequirePermissions(AdminPermission.SUPPORT_TICKET_WRITE)
  async sendMessage(
    @Request() req: any,
    @Body()
    body: {
      phoneNumber: string;
      templateName: string;
      variables?: Record<string, any>;
      userId?: string;
      bookingId?: string;
    },
  ) {
    const adminUserId = req.user?.userId || req.user?.id || 'admin';
    return this.whatsappService.sendManualMessage(body, adminUserId);
  }

  @Get('messages/:id/timeline')
  async getMessageTimeline(@Param('id') id: string) {
    return this.whatsappService.getMessageTimeline(id);
  }
}
