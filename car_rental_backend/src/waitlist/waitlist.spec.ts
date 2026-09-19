import { Test, TestingModule } from '@nestjs/testing';
import { WaitlistService } from './waitlist.service';
import { WaitlistController } from './waitlist.controller';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';

describe('WaitlistService and WaitlistController', () => {
  let service: WaitlistService;
  let controller: WaitlistController;
  let prisma: any;

  const mockEntry = {
    id: 'wait-1',
    customerId: 'cust-1',
    carId: 'car-1',
    city: 'Mumbai',
    carCategory: 'SUV',
    startDate: new Date('2026-10-01T10:00:00Z'),
    endDate: new Date('2026-10-05T10:00:00Z'),
    status: 'ACTIVE',
    notifiedAt: null,
    convertedAt: null,
    notes: 'Need automatic transmission',
    createdAt: new Date(),
    car: {
      id: 'car-1',
      make: 'Hyundai',
      model: 'Creta',
      year: 2024,
      photos: [],
      pricePerDay: 3500,
    },
  };

  beforeEach(async () => {
    prisma = {
      waitlistEntry: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [WaitlistController],
      providers: [
        WaitlistService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<WaitlistService>(WaitlistService);
    controller = module.get<WaitlistController>(WaitlistController);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
    expect(controller).toBeDefined();
  });

  describe('joinWaitlist', () => {
    it('creates waitlist entry when inputs are valid', async () => {
      prisma.waitlistEntry.findFirst.mockResolvedValue(null);
      prisma.waitlistEntry.create.mockResolvedValue(mockEntry);

      const res = await service.joinWaitlist('cust-1', {
        carId: 'car-1',
        city: 'Mumbai',
        carCategory: 'SUV',
        startDate: '2026-10-01T10:00:00Z',
        endDate: '2026-10-05T10:00:00Z',
        notes: 'Need automatic transmission',
      });

      expect(res).toEqual(mockEntry);
      expect(prisma.waitlistEntry.create).toHaveBeenCalled();
    });

    it('rejects if endDate is before startDate', async () => {
      await expect(
        service.joinWaitlist('cust-1', {
          city: 'Mumbai',
          startDate: '2026-10-05T10:00:00Z',
          endDate: '2026-10-01T10:00:00Z',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects if city is omitted', async () => {
      await expect(
        service.joinWaitlist('cust-1', {
          city: '',
          startDate: '2026-10-01T10:00:00Z',
          endDate: '2026-10-05T10:00:00Z',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects duplicate overlapping waitlist for same vehicle', async () => {
      prisma.waitlistEntry.findFirst.mockResolvedValue(mockEntry);

      await expect(
        service.joinWaitlist('cust-1', {
          carId: 'car-1',
          city: 'Mumbai',
          startDate: '2026-10-02T10:00:00Z',
          endDate: '2026-10-04T10:00:00Z',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('cancelWaitlistEntry', () => {
    it('cancels entry for authorized customer', async () => {
      prisma.waitlistEntry.findUnique.mockResolvedValue(mockEntry);
      prisma.waitlistEntry.update.mockResolvedValue({ ...mockEntry, status: 'CANCELLED' });

      const res = await service.cancelWaitlistEntry('wait-1', 'cust-1');
      expect(res.status).toBe('CANCELLED');
      expect(prisma.waitlistEntry.update).toHaveBeenCalledWith({
        where: { id: 'wait-1' },
        data: { status: 'CANCELLED' },
      });
    });

    it('rejects cancellation by non-owner', async () => {
      prisma.waitlistEntry.findUnique.mockResolvedValue(mockEntry);
      await expect(service.cancelWaitlistEntry('wait-1', 'intruder-user')).rejects.toThrow(BadRequestException);
    });

    it('throws NotFoundException if entry not found', async () => {
      prisma.waitlistEntry.findUnique.mockResolvedValue(null);
      await expect(service.cancelWaitlistEntry('wait-none', 'cust-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('notifyWaitlistEntry', () => {
    it('marks waitlist entry as NOTIFIED with timestamp', async () => {
      prisma.waitlistEntry.findUnique.mockResolvedValue(mockEntry);
      prisma.waitlistEntry.update.mockResolvedValue({ ...mockEntry, status: 'NOTIFIED', notifiedAt: new Date() });

      const res = await service.notifyWaitlistEntry('wait-1');
      expect(res.status).toBe('NOTIFIED');
      expect(prisma.waitlistEntry.update).toHaveBeenCalledWith({
        where: { id: 'wait-1' },
        data: { status: 'NOTIFIED', notifiedAt: expect.any(Date) },
      });
    });
  });

  describe('WaitlistController', () => {
    it('POST /waitlist delegates to service with customerId', async () => {
      prisma.waitlistEntry.findFirst.mockResolvedValue(null);
      prisma.waitlistEntry.create.mockResolvedValue(mockEntry);

      const req = { user: { userId: 'cust-1' } };
      const res = await controller.joinWaitlist(req, {
        city: 'Mumbai',
        startDate: '2026-10-01T10:00:00Z',
        endDate: '2026-10-05T10:00:00Z',
      });
      expect(res).toEqual(mockEntry);
    });

    it('GET /waitlist/my returns list of user waitlist entries', async () => {
      prisma.waitlistEntry.findMany.mockResolvedValue([mockEntry]);
      const req = { user: { userId: 'cust-1' } };
      const res = await controller.getMyWaitlist(req);
      expect(res).toEqual([mockEntry]);
    });
  });
});
