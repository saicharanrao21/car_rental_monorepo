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
import { SupportTicketsService } from './support-tickets.service';
import { CreateTicketDto } from './dto/create-ticket.dto';
import { ReplyTicketDto } from './dto/reply-ticket.dto';
import { UpdateTicketStatusDto } from './dto/update-ticket-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, TicketCategory, TicketPriority, TicketStatus } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class SupportTicketsController {
  constructor(private readonly supportService: SupportTicketsService) {}

  /**
   * Customer creates a new support ticket.
   */
  @Post('support/tickets')
  @Roles(Role.CUSTOMER)
  async createTicket(@Request() req: any, @Body() dto: CreateTicketDto) {
    return this.supportService.createTicket(req.user.userId, dto);
  }

  /**
   * Customer retrieves all of their support tickets.
   */
  @Get('support/tickets/my')
  @Roles(Role.CUSTOMER)
  async getMyTickets(@Request() req: any) {
    return this.supportService.getMyTickets(req.user.userId);
  }

  /**
   * Retrieves single support ticket by ID.
   */
  @Get('support/tickets/:id')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.SUPPORT_AGENT, Role.ADMIN)
  async getTicketById(@Request() req: any, @Param('id') id: string) {
    return this.supportService.getTicketById(id, {
      userId: req.user.userId,
      role: req.user.role,
    });
  }

  /**
   * Posts a reply message or internal staff note to a support ticket.
   */
  @Post('support/tickets/:id/reply')
  @Roles(Role.CUSTOMER, Role.SUPPORT_AGENT, Role.ADMIN)
  async replyTicket(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: ReplyTicketDto,
  ) {
    return this.supportService.replyTicket(id, dto, {
      userId: req.user.userId,
      role: req.user.role,
    });
  }

  /**
   * Closes a resolved ticket.
   */
  @Post('support/tickets/:id/close')
  @Roles(Role.CUSTOMER, Role.SUPPORT_AGENT, Role.ADMIN)
  async closeTicket(@Request() req: any, @Param('id') id: string) {
    return this.supportService.closeTicket(id, {
      userId: req.user.userId,
      role: req.user.role,
    });
  }

  /**
   * Customer reopens a closed or resolved ticket.
   */
  @Post('support/tickets/:id/reopen')
  @Roles(Role.CUSTOMER)
  async reopenTicket(
    @Request() req: any,
    @Param('id') id: string,
    @Body('reason') reason: string,
  ) {
    return this.supportService.reopenTicket(
      id,
      req.user.userId,
      reason || 'Customer requested reopening.',
    );
  }

  /**
   * Admin / Support Agent retrieves all tickets with filters.
   */
  @Get('admin/support/tickets')
  @Roles(Role.SUPPORT_AGENT, Role.ADMIN)
  async getAllTickets(
    @Query('status') status?: TicketStatus,
    @Query('category') category?: TicketCategory,
    @Query('priority') priority?: TicketPriority,
    @Query('assignedToUserId') assignedToUserId?: string,
    @Query('city') city?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.supportService.getAllTickets({
      status,
      category,
      priority,
      assignedToUserId,
      city,
      search,
      limit: limit ? parseInt(limit, 10) : undefined,
      offset: offset ? parseInt(offset, 10) : undefined,
    });
  }

  /**
   * Admin / Support Agent updates ticket status, priority, or assignment.
   */
  @Patch('admin/support/tickets/:id/status')
  @Roles(Role.SUPPORT_AGENT, Role.ADMIN)
  async updateTicketStatus(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateTicketStatusDto,
  ) {
    return this.supportService.updateTicketStatus(id, dto, req.user.userId);
  }
}
