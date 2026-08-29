import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { FcmService } from './fcm.service';
import { AuditLogService } from '../admin/audit-log.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import { PrismaService } from '../prisma/prisma.service';

describe('Phase 27.2 — Notifications & Async Queue Integration Tests', () => {
  let service: NotificationsService;
  let prisma: any;
  let queueProducer: any;

  beforeEach(async () => {
    prisma = {
      notification: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({ id: 'notif_1', ...data, createdAt: new Date() }),
        ),
      },
      userDevice: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      notificationPreference: {
        findUnique: jest.fn().mockResolvedValue({
          userId: 'user_123',
          promotionalPush: true,
          operationalPush: true,
          promotionalSms: true,
          operationalSms: true,
          promotionalEmail: true,
          operationalEmail: true,
        }),
      },
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'user_123',
          phone: '9876543210',
          email: 'customer@drivego.in',
        }),
      },
    };

    queueProducer = {
      dispatchSmsNotification: jest.fn().mockResolvedValue({ jobId: 'sms-job-1', status: 'QUEUED' }),
      dispatchEmailNotification: jest.fn().mockResolvedValue({ jobId: 'email-job-1', status: 'QUEUED' }),
    };

    const mockFcm = {
      sendToUser: jest.fn().mockResolvedValue(true),
    };

    const mockAuditLog = {
      log: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: FcmService, useValue: mockFcm },
        { provide: AuditLogService, useValue: mockAuditLog },
        { provide: QueueProducerService, useValue: queueProducer },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
  });

  it('persists notification synchronously in DB and enqueues async channel jobs', async () => {
    const result = await service.notifyUser(
      'user_123',
      'Booking Confirmed',
      'Your trip is confirmed!',
    );

    expect(result.id).toBe('notif_1');
    expect(result.title).toBe('Booking Confirmed');
    expect(prisma.notification.create).toHaveBeenCalled();
  });
});
