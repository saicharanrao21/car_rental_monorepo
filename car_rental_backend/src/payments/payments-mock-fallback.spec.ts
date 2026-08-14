import { ConfigService } from '@nestjs/config';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('PaymentsService Mock Fallback Hardening (Phase 2B)', () => {
  let mockPrisma: any;
  let mockNotifications: any;

  beforeEach(() => {
    mockPrisma = {
      booking: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      payment: {
        create: jest.fn(),
        update: jest.fn(),
      },
      auditLog: {
        create: jest.fn(),
      },
    };
    mockNotifications = {
      sendToUser: jest.fn(),
    };
  });

  it('should throw fatal error if RAZORPAY_USE_MOCK is true in production', () => {
    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'production';
        if (key === 'RAZORPAY_USE_MOCK') return 'true';
        return '';
      }),
    } as unknown as ConfigService;

    expect(
      () =>
        new PaymentsService(
          mockPrisma as PrismaService,
          configService,
          mockNotifications as NotificationsService,
        ),
    ).toThrow(/RAZORPAY_USE_MOCK is set to true, but NODE_ENV is production/);
  });

  it('should allow mock mode in development environment if RAZORPAY_USE_MOCK is true', () => {
    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'development';
        if (key === 'RAZORPAY_USE_MOCK') return 'true';
        return '';
      }),
    } as unknown as ConfigService;

    const service = new PaymentsService(
      mockPrisma as PrismaService,
      configService,
      mockNotifications as NotificationsService,
    );
    expect(service).toBeDefined();
  });
});
