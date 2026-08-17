import { Test, TestingModule } from '@nestjs/testing';
import { SupportTicketsService } from './support-tickets.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  Role,
  TicketCategory,
  TicketPriority,
  TicketStatus,
} from '@prisma/client';
import { ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';

describe('SupportTicketsService', () => {
  let service: SupportTicketsService;
  let prisma: PrismaService;

  const mockPrisma = {
    supportTicket: {
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    ticketMessage: {
      create: jest.fn(),
    },
    booking: {
      findUnique: jest.fn(),
    },
  };

  const mockNotifications = {
    notifyUser: jest.fn().mockResolvedValue(undefined),
  };

  const mockAuditLog = {
    log: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SupportTicketsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: AuditLogService, useValue: mockAuditLog },
      ],
    }).compile();

    service = module.get<SupportTicketsService>(SupportTicketsService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createTicket', () => {
    it('should create a support ticket with generated ticket number', async () => {
      mockPrisma.supportTicket.count.mockResolvedValue(4);
      mockPrisma.supportTicket.create.mockResolvedValue({
        id: 'tkt_123',
        ticketNumber: 'TKT-2026-08-00005',
        customerId: 'user_cust_1',
        category: TicketCategory.BOOKING,
        priority: TicketPriority.NORMAL,
        subject: 'Need help with car delivery',
        description: 'Where is the car?',
        status: TicketStatus.OPEN,
      });

      const result = await service.createTicket('user_cust_1', {
        category: TicketCategory.BOOKING,
        subject: 'Need help with car delivery',
        description: 'Where is the car?',
      });

      expect(result.id).toBe('tkt_123');
      expect(mockPrisma.supportTicket.create).toHaveBeenCalled();
      expect(mockNotifications.notifyUser).toHaveBeenCalled();
    });

    it('should throw ForbiddenException if customer does not own linked booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_999',
        customerId: 'other_cust_2',
      });

      await expect(
        service.createTicket('user_cust_1', {
          category: TicketCategory.BOOKING,
          subject: 'Issue',
          description: 'Desc',
          bookingId: 'book_999',
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('getTicketById (IDOR & Internal Note Filtering)', () => {
    it('should throw ForbiddenException when Customer A accesses Customer B ticket', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt_1',
        customerId: 'user_cust_2',
        messages: [],
      });

      await expect(
        service.getTicketById('tkt_1', {
          userId: 'user_cust_1',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should filter out internal messages for customer viewer', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt_1',
        customerId: 'user_cust_1',
        messages: [
          { id: 'msg_1', message: 'Hello', isInternal: false },
          { id: 'msg_2', message: 'Internal staff note', isInternal: true },
        ],
      });

      const result = await service.getTicketById('tkt_1', {
        userId: 'user_cust_1',
        role: Role.CUSTOMER,
      });

      expect(result.messages.length).toBe(1);
      expect(result.messages[0].id).toBe('msg_1');
    });
  });

  describe('updateTicketStatus', () => {
    it('should reject invalid state transitions', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt_1',
        status: TicketStatus.CLOSED,
      });

      await expect(
        service.updateTicketStatus(
          'tkt_1',
          { status: TicketStatus.WAITING_FOR_CUSTOMER },
          'admin_1',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should update status and audit log when valid', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt_1',
        status: TicketStatus.OPEN,
        customerId: 'cust_1',
        ticketNumber: 'TKT-101',
      });
      mockPrisma.supportTicket.update.mockResolvedValue({
        id: 'tkt_1',
        status: TicketStatus.IN_PROGRESS,
      });

      const result = await service.updateTicketStatus(
        'tkt_1',
        { status: TicketStatus.IN_PROGRESS },
        'admin_1',
      );

      expect(result.status).toBe(TicketStatus.IN_PROGRESS);
      expect(mockAuditLog.log).toHaveBeenCalled();
    });
  });
});
