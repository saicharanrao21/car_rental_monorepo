import { SupportTicketsService } from './support-tickets.service';
import { TicketPriority, TicketCategory, TicketStatus, Role } from '@prisma/client';
import { BadRequestException, ForbiddenException } from '@nestjs/common';

describe('SupportSlaEscalation (Phase 27.5)', () => {
  let service: SupportTicketsService;
  let mockPrisma: any;
  let mockNotifications: any;
  let mockAudit: any;
  let mockSystemConfig: any;

  beforeEach(() => {
    mockPrisma = {
      supportTicket: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      ticketMessage: {
        create: jest.fn(),
      },
      booking: {
        findUnique: jest.fn(),
      },
    };

    mockNotifications = {
      notifyUser: jest.fn().mockResolvedValue(undefined),
    };

    mockAudit = {
      log: jest.fn().mockResolvedValue(undefined),
    };

    mockSystemConfig = {
      getSupportSlaConfig: jest.fn().mockResolvedValue({
        firstResponseMinutesUrgent: 15,
        firstResponseMinutesHigh: 60,
        firstResponseMinutesNormal: 240,
        resolutionMinutesUrgent: 120,
        resolutionMinutesHigh: 480,
        resolutionMinutesNormal: 1440,
        maxOpenTicketsPerCustomer: 5,
      }),
    };

    service = new SupportTicketsService(
      mockPrisma,
      mockNotifications,
      mockAudit,
      mockSystemConfig,
    );
  });

  describe('SLA Deadline Calculation', () => {
    it('should compute tight SLA deadlines for URGENT tickets (15m response, 120m resolution)', async () => {
      mockPrisma.supportTicket.create.mockImplementation((args: any) => ({
        id: 'tkt-urg-1',
        ticketNumber: 'TKT-2026-08-00001',
        ...args.data,
      }));

      const before = Date.now();
      const ticket = await service.createTicket('cust-1', {
        category: TicketCategory.VEHICLE_BREAKDOWN,
        priority: TicketPriority.URGENT,
        subject: 'Car broken down on highway',
        description: 'Engine smoking near toll booth',
      });

      const responseDiffMinutes =
        (ticket.slaFirstResponseDue!.getTime() - before) / 60000;
      const resolutionDiffMinutes =
        (ticket.slaResolutionDue!.getTime() - before) / 60000;

      expect(responseDiffMinutes).toBeCloseTo(15, 0);
      expect(resolutionDiffMinutes).toBeCloseTo(120, 0);
    });

    it('should reject ticket creation when customer reaches max open tickets limit', async () => {
      mockPrisma.supportTicket.count.mockResolvedValue(5); // 5 open tickets

      await expect(
        service.createTicket('cust-spammer', {
          category: TicketCategory.GENERAL_INQUIRY,
          priority: TicketPriority.NORMAL,
          subject: 'Another ticket',
          description: 'Spamming tickets',
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('Ticket Escalation & Internal Notes', () => {
    it('should escalate ticket to higher tier and log internal note and audit log', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt-1',
        ticketNumber: 'TKT-2026-08-00001',
        escalationTier: 1,
        priority: TicketPriority.HIGH,
      });

      mockPrisma.supportTicket.update.mockImplementation((args: any) => ({
        id: 'tkt-1',
        ...args.data,
      }));

      const escalated = await service.escalateTicket(
        'tkt-1',
        'Customer demands immediate manager intervention for refund issue',
        'admin-ops-1',
      );

      expect(escalated.escalationTier).toBe(2);
      expect(escalated.priority).toBe(TicketPriority.URGENT);
      expect(mockPrisma.ticketMessage.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            isInternal: true,
            message: expect.stringContaining('[ESCALATION - Tier 2]'),
          }),
        }),
      );
      expect(mockAudit.log).toHaveBeenCalledWith(
        'admin-ops-1',
        'SUPPORT_TICKET_ESCALATED',
        'SupportTicket',
        'tkt-1',
        expect.any(Object),
      );
    });
  });

  describe('Customer Data Isolation & Internal Note Protection', () => {
    it('should strictly filter out internal notes when customer views ticket', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt-100',
        customerId: 'cust-1',
        messages: [
          { id: 'm1', message: 'Hello support', isInternal: false },
          { id: 'm2', message: 'CONFIDENTIAL: Customer flagged for chargeback risk', isInternal: true },
          { id: 'm3', message: 'We are investigating your issue', isInternal: false },
        ],
      });

      const ticket = await service.getTicketById('tkt-100', {
        userId: 'cust-1',
        role: Role.CUSTOMER,
      });

      expect(ticket.messages.length).toBe(2);
      expect(ticket.messages.some((m: any) => m.isInternal)).toBe(false);
      expect(ticket.messages.some((m: any) => m.message.includes('CONFIDENTIAL'))).toBe(false);
    });

    it('should reject access if customer tries to view another customer ticket', async () => {
      mockPrisma.supportTicket.findUnique.mockResolvedValue({
        id: 'tkt-victim',
        customerId: 'cust-VICTIM',
        messages: [],
      });

      await expect(
        service.getTicketById('tkt-victim', {
          userId: 'cust-ATTACKER',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
