import { Test, TestingModule } from '@nestjs/testing';
import { EmergencyAssistanceService } from './emergency-assistance.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../admin/audit-log.service';
import {
  IncidentType,
  TicketPriority,
  EmergencyStatus,
} from '@prisma/client';
import { ForbiddenException, ConflictException } from '@nestjs/common';

describe('EmergencyAssistanceService', () => {
  let service: EmergencyAssistanceService;
  let prisma: PrismaService;

  const mockPrisma = {
    emergencyRequest: {
      count: jest.fn().mockResolvedValue(0),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    booking: {
      findUnique: jest.fn(),
    },
    vendor: {
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
        EmergencyAssistanceService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: AuditLogService, useValue: mockAuditLog },
      ],
    }).compile();

    service = module.get<EmergencyAssistanceService>(EmergencyAssistanceService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createRequest', () => {
    it('should create an SOS request with generated request number', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'cust_1',
        carId: 'car_1',
        vendorId: 'vendor_1',
        pickupLocation: 'Bandra, Mumbai',
        car: { make: 'Hyundai', model: 'Creta', registrationNumber: 'MH02AB1234' },
        vendor: { id: 'vendor_1', businessName: 'Speedy Rentals', city: 'Mumbai' },
      });
      mockPrisma.emergencyRequest.findFirst.mockResolvedValue(null);
      mockPrisma.emergencyRequest.count.mockResolvedValue(2);
      mockPrisma.emergencyRequest.create.mockResolvedValue({
        id: 'sos_123',
        requestNumber: 'SOS-2026-08-00003',
        bookingId: 'book_1',
        customerId: 'cust_1',
        incidentType: IncidentType.FLAT_TYRE,
        urgency: TicketPriority.URGENT,
        status: EmergencyStatus.REQUESTED,
      });

      const result = await service.createRequest('cust_1', {
        bookingId: 'book_1',
        incidentType: IncidentType.FLAT_TYRE,
      });

      expect(result.id).toBe('sos_123');
      expect(mockPrisma.emergencyRequest.create).toHaveBeenCalled();
      expect(mockNotifications.notifyUser).toHaveBeenCalled();
    });

    it('should reject duplicate SOS requests on the same active booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'cust_1',
        car: {},
        vendor: {},
      });
      mockPrisma.emergencyRequest.findFirst.mockResolvedValue({
        id: 'sos_existing',
        requestNumber: 'SOS-2026-08-00001',
        status: EmergencyStatus.REQUESTED,
      });

      await expect(
        service.createRequest('cust_1', {
          bookingId: 'book_1',
          incidentType: IncidentType.BREAKDOWN,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw ForbiddenException if customer does not own booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'book_1',
        customerId: 'other_cust',
        car: {},
        vendor: {},
      });

      await expect(
        service.createRequest('cust_1', {
          bookingId: 'book_1',
          incidentType: IncidentType.ACCIDENT,
        }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('updateStatus', () => {
    it('should update status, assign provider, and notify customer', async () => {
      mockPrisma.emergencyRequest.findUnique.mockResolvedValue({
        id: 'sos_1',
        customerId: 'cust_1',
        status: EmergencyStatus.REQUESTED,
      });
      mockPrisma.emergencyRequest.update.mockResolvedValue({
        id: 'sos_1',
        status: EmergencyStatus.ASSIGNED,
        assignedProviderName: 'QuickTow Logistics',
      });

      const result = await service.updateStatus(
        'sos_1',
        {
          status: EmergencyStatus.ASSIGNED,
          assignedProviderName: 'QuickTow Logistics',
          assignedProviderPhone: '+919876543210',
          estimatedEtaMinutes: 25,
        },
        'admin_user_1',
      );

      expect(result.status).toBe(EmergencyStatus.ASSIGNED);
      expect(mockAuditLog.log).toHaveBeenCalled();
      expect(mockNotifications.notifyUser).toHaveBeenCalled();
    });
  });
});
