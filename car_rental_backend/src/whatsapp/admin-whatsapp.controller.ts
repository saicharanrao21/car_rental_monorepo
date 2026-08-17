import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { WhatsAppService } from './whatsapp.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import {
  Role,
  WhatsAppMessageStatus,
  WhatsAppMessageType,
} from '@prisma/client';

@Controller('admin/whatsapp')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminWhatsAppController {
  constructor(private readonly whatsappService: WhatsAppService) {}

  @Get('summary')
  async getSummary() {
    return this.whatsappService.getSummary();
  }

  @Get('messages')
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
  async resendMessage(@Param('id') id: string, @Request() req: any) {
    const adminUserId = req.user?.userId || req.user?.id || 'admin';
    return this.whatsappService.resendMessage(id, adminUserId);
  }
}
