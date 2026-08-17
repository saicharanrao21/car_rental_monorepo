import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  Role,
  TicketStatus,
  TicketPriority,
  TicketCategory,
  SupportTicket,
  TicketMessage,
} from '@prisma/client';
import { CreateTicketDto } from './dto/create-ticket.dto';
import { ReplyTicketDto } from './dto/reply-ticket.dto';
import { UpdateTicketStatusDto } from './dto/update-ticket-status.dto';

@Injectable()
export class SupportTicketsService {
  private readonly logger = new Logger(SupportTicketsService.name);

  // Controlled state transition matrix
  private readonly validTransitions: Record<TicketStatus, TicketStatus[]> = {
    [TicketStatus.OPEN]: [
      TicketStatus.ASSIGNED,
      TicketStatus.IN_PROGRESS,
      TicketStatus.WAITING_FOR_CUSTOMER,
      TicketStatus.WAITING_FOR_VENDOR,
      TicketStatus.RESOLVED,
      TicketStatus.CLOSED,
    ],
    [TicketStatus.ASSIGNED]: [
      TicketStatus.IN_PROGRESS,
      TicketStatus.WAITING_FOR_CUSTOMER,
      TicketStatus.WAITING_FOR_VENDOR,
      TicketStatus.RESOLVED,
      TicketStatus.CLOSED,
    ],
    [TicketStatus.IN_PROGRESS]: [
      TicketStatus.WAITING_FOR_CUSTOMER,
      TicketStatus.WAITING_FOR_VENDOR,
      TicketStatus.RESOLVED,
      TicketStatus.CLOSED,
    ],
    [TicketStatus.WAITING_FOR_CUSTOMER]: [
      TicketStatus.IN_PROGRESS,
      TicketStatus.RESOLVED,
      TicketStatus.CLOSED,
    ],
    [TicketStatus.WAITING_FOR_VENDOR]: [
      TicketStatus.IN_PROGRESS,
      TicketStatus.RESOLVED,
      TicketStatus.CLOSED,
    ],
    [TicketStatus.RESOLVED]: [
      TicketStatus.CLOSED,
      TicketStatus.IN_PROGRESS, // Customer reopens
    ],
    [TicketStatus.CLOSED]: [
      TicketStatus.IN_PROGRESS, // Admin reopens
    ],
  };

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly auditLogService: AuditLogService,
  ) {}

  /**
   * Generates sequential ticket numbers: TKT-YYYY-MM-XXXXX
   */
  private async generateTicketNumber(): Promise<string> {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const prefix = `TKT-${year}-${month}-`;

    const count = await this.prisma.supportTicket.count({
      where: {
        ticketNumber: { startsWith: prefix },
      },
    });

    return `${prefix}${String(count + 1).padStart(5, '0')}`;
  }

  /**
   * Customer creates a new support ticket.
   */
  async createTicket(
    customerId: string,
    dto: CreateTicketDto,
  ): Promise<SupportTicket> {
    // If bookingId is provided, verify customer ownership
    if (dto.bookingId) {
      const booking = await this.prisma.booking.findUnique({
        where: { id: dto.bookingId },
      });
      if (!booking) {
        throw new NotFoundException('Linked booking not found.');
      }
      if (booking.customerId !== customerId) {
        throw new ForbiddenException(
          'Access denied: You do not own this booking.',
        );
      }
    }

    const ticketNumber = await this.generateTicketNumber();

    const ticket = await this.prisma.supportTicket.create({
      data: {
        ticketNumber,
        customerId,
        bookingId: dto.bookingId || null,
        category: dto.category,
        priority: dto.priority || TicketPriority.NORMAL,
        subject: dto.subject,
        description: dto.description,
        status: TicketStatus.OPEN,
        messages: {
          create: {
            senderId: customerId,
            senderRole: Role.CUSTOMER,
            message: dto.description,
            attachments: dto.attachments || [],
            isInternal: false,
          },
        },
      },
      include: {
        customer: { select: { id: true, name: true, phone: true, email: true } },
        booking: { select: { id: true, tripType: true, status: true, startDate: true, endDate: true } },
        messages: true,
      },
    });

    // Notify customer confirmation
    await this.notificationsService.notifyUser(
      customerId,
      'Support Ticket Received',
      `Your support ticket #${ticketNumber} has been received. Our team will respond shortly.`,
    );

    this.logger.log(`Created support ticket #${ticketNumber} for customer ${customerId}`);
    return ticket;
  }

  /**
   * Customer retrieves their own tickets.
   */
  async getMyTickets(customerId: string) {
    return this.prisma.supportTicket.findMany({
      where: { customerId },
      include: {
        booking: {
          select: {
            id: true,
            tripType: true,
            status: true,
            car: { select: { make: true, model: true } },
          },
        },
        _count: { select: { messages: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Retrieves ticket details by ID with IDOR protection.
   */
  async getTicketById(ticketId: string, user: { userId: string; role: Role }) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: {
        customer: { select: { id: true, name: true, phone: true, email: true } },
        booking: {
          select: {
            id: true,
            tripType: true,
            status: true,
            startDate: true,
            endDate: true,
            car: { select: { make: true, model: true, registrationNumber: true } },
            vendor: { select: { id: true, businessName: true, city: true } },
          },
        },
        assignedToUser: { select: { id: true, name: true, email: true, role: true } },
        messages: {
          include: {
            sender: { select: { id: true, name: true, role: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!ticket) {
      throw new NotFoundException('Support ticket not found.');
    }

    // Role-based access check
    if (user.role === Role.CUSTOMER && ticket.customerId !== user.userId) {
      throw new ForbiddenException('Access denied: You do not own this ticket.');
    }

    if (user.role === Role.VENDOR) {
      // Vendors can only view tickets if linked to their booking
      if (!ticket.booking || ticket.booking.vendor.id !== user.userId) {
        throw new ForbiddenException(
          'Access denied: You are not authorized to view this ticket.',
        );
      }
    }

    // Filter out internal messages for customers and vendors
    if (user.role === Role.CUSTOMER || user.role === Role.VENDOR) {
      ticket.messages = ticket.messages.filter((m) => !m.isInternal);
    }

    return ticket;
  }

  /**
   * Adds a reply or internal note to an existing ticket.
   */
  async replyTicket(
    ticketId: string,
    dto: ReplyTicketDto,
    user: { userId: string; role: Role },
  ): Promise<TicketMessage> {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) {
      throw new NotFoundException('Support ticket not found.');
    }

    if (user.role === Role.CUSTOMER && ticket.customerId !== user.userId) {
      throw new ForbiddenException('Access denied: You do not own this ticket.');
    }

    if (ticket.status === TicketStatus.CLOSED) {
      throw new BadRequestException(
        'Cannot reply to a closed ticket. Please reopen it first.',
      );
    }

    // Only Admin / Support Agent can post internal notes
    const isInternal =
      (user.role === Role.ADMIN || user.role === Role.SUPPORT_AGENT) &&
      Boolean(dto.isInternal);

    const message = await this.prisma.ticketMessage.create({
      data: {
        ticketId,
        senderId: user.userId,
        senderRole: user.role,
        message: dto.message,
        attachments: dto.attachments || [],
        isInternal,
      },
      include: {
        sender: { select: { id: true, name: true, role: true } },
      },
    });

    // Auto-update ticket status based on reply
    let nextStatus = ticket.status;
    if (user.role === Role.CUSTOMER) {
      if (
        ticket.status === TicketStatus.WAITING_FOR_CUSTOMER ||
        ticket.status === TicketStatus.OPEN
      ) {
        nextStatus = TicketStatus.IN_PROGRESS;
      }
    } else if (
      user.role === Role.ADMIN ||
      user.role === Role.SUPPORT_AGENT
    ) {
      if (!isInternal) {
        nextStatus = TicketStatus.WAITING_FOR_CUSTOMER;
        // Notify customer that support replied
        await this.notificationsService.notifyUser(
          ticket.customerId,
          'Support Response',
          `Support has replied to your ticket #${ticket.ticketNumber}.`,
        );
      }
    }

    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: nextStatus,
        updatedAt: new Date(),
      },
    });

    return message;
  }

  /**
   * Admin/Support Agent updates ticket status, priority, or assignment.
   */
  async updateTicketStatus(
    ticketId: string,
    dto: UpdateTicketStatusDto,
    adminUserId: string,
  ): Promise<SupportTicket> {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) {
      throw new NotFoundException('Support ticket not found.');
    }

    // Validate transition
    if (ticket.status !== dto.status) {
      const allowed = this.validTransitions[ticket.status] || [];
      if (!allowed.includes(dto.status)) {
        throw new BadRequestException(
          `Invalid ticket status transition from '${ticket.status}' to '${dto.status}'.`,
        );
      }
    }

    const resolvedAt =
      dto.status === TicketStatus.RESOLVED && !ticket.resolvedAt
        ? new Date()
        : ticket.resolvedAt;
    const closedAt =
      dto.status === TicketStatus.CLOSED && !ticket.closedAt
        ? new Date()
        : ticket.closedAt;

    const updated = await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: dto.status,
        priority: dto.priority || ticket.priority,
        assignedToUserId: dto.assignedToUserId !== undefined ? dto.assignedToUserId : ticket.assignedToUserId,
        resolvedAt,
        closedAt,
      },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        assignedToUser: { select: { id: true, name: true, role: true } },
      },
    });

    // Post internal resolution note if provided
    if (dto.resolutionNote) {
      await this.prisma.ticketMessage.create({
        data: {
          ticketId,
          senderId: adminUserId,
          senderRole: Role.ADMIN,
          message: `[Status Update: ${dto.status}] ${dto.resolutionNote}`,
          isInternal: true,
        },
      });
    }

    // Audit log
    await this.auditLogService.log(
      adminUserId,
      'SUPPORT_TICKET_STATUS_UPDATED',
      'SupportTicket',
      ticketId,
      { previousStatus: ticket.status, newStatus: dto.status },
    );

    // Notify customer if resolved
    if (dto.status === TicketStatus.RESOLVED) {
      await this.notificationsService.notifyUser(
        ticket.customerId,
        'Ticket Resolved',
        `Your ticket #${ticket.ticketNumber} has been marked as resolved.`,
      );
    }

    return updated;
  }

  /**
   * Customer or Admin closes a resolved ticket.
   */
  async closeTicket(
    ticketId: string,
    user: { userId: string; role: Role },
  ): Promise<SupportTicket> {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) {
      throw new NotFoundException('Support ticket not found.');
    }

    if (user.role === Role.CUSTOMER && ticket.customerId !== user.userId) {
      throw new ForbiddenException('Access denied: You do not own this ticket.');
    }

    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: TicketStatus.CLOSED,
        closedAt: new Date(),
      },
    });
  }

  /**
   * Customer reopens a resolved ticket.
   */
  async reopenTicket(
    ticketId: string,
    customerId: string,
    reason: string,
  ): Promise<SupportTicket> {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });

    if (!ticket) {
      throw new NotFoundException('Support ticket not found.');
    }

    if (ticket.customerId !== customerId) {
      throw new ForbiddenException('Access denied: You do not own this ticket.');
    }

    if (
      ticket.status !== TicketStatus.RESOLVED &&
      ticket.status !== TicketStatus.CLOSED
    ) {
      throw new BadRequestException('Only resolved or closed tickets can be reopened.');
    }

    const updated = await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: TicketStatus.IN_PROGRESS,
        resolvedAt: null,
        closedAt: null,
      },
    });

    // Add customer reopen message
    await this.prisma.ticketMessage.create({
      data: {
        ticketId,
        senderId: customerId,
        senderRole: Role.CUSTOMER,
        message: `[Ticket Reopened] ${reason}`,
        isInternal: false,
      },
    });

    return updated;
  }

  /**
   * Admin retrieves all tickets with multi-filter queries.
   */
  async getAllTickets(query: {
    status?: TicketStatus;
    category?: TicketCategory;
    priority?: TicketPriority;
    assignedToUserId?: string;
    city?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) {
    const where: any = {};

    if (query.status) where.status = query.status;
    if (query.category) where.category = query.category;
    if (query.priority) where.priority = query.priority;
    if (query.assignedToUserId) where.assignedToUserId = query.assignedToUserId;

    if (query.city) {
      where.booking = {
        vendor: { city: query.city },
      };
    }

    if (query.search) {
      where.OR = [
        { ticketNumber: { contains: query.search, mode: 'insensitive' } },
        { subject: { contains: query.search, mode: 'insensitive' } },
        { customer: { name: { contains: query.search, mode: 'insensitive' } } },
        { customer: { phone: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const limit = query.limit || 50;
    const offset = query.offset || 0;

    const [tickets, total] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, phone: true } },
          booking: {
            select: {
              id: true,
              tripType: true,
              vendor: { select: { businessName: true, city: true } },
            },
          },
          assignedToUser: { select: { id: true, name: true, role: true } },
          _count: { select: { messages: true } },
        },
        orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
        take: limit,
        skip: offset,
      }),
      this.prisma.supportTicket.count({ where }),
    ]);

    return { tickets, total, limit, offset };
  }
}
