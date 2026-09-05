import { NotificationOrchestratorService } from './notification-orchestrator.service';
import { FcmService } from './fcm.service';
import { SmsProvider } from './providers/sms-provider.service';
import { EmailProvider } from './providers/email-provider.service';
import { WhatsAppProvider } from '../whatsapp/whatsapp-provider.service';
import { QueueProducerService } from '../queues/queue-producer.service';
import { NotificationChannel, DeliveryStatus, NotificationPriority } from '@prisma/client';

describe('Phase 31: Multi-Channel Operational Notification Platform', () => {
  let orchestrator: NotificationOrchestratorService;
  let mockPrisma: any;
  let mockFcm: any;
  let mockSms: any;
  let mockEmail: any;
  let mockWhatsApp: any;
  let mockQueueProducer: any;

  const testUser = {
    id: 'usr_cust_01',
    name: 'Aarav Mehta',
    phone: '+919876543210',
    email: 'aarav@example.com',
  };

  const testPrefs = {
    userId: 'usr_cust_01',
    operationalPush: true,
    operationalSms: true,
    operationalEmail: true,
    operationalWhatsApp: true,
    promotionalPush: false,
    promotionalSms: false,
    promotionalEmail: false,
    promotionalWhatsApp: false,
  };

  beforeEach(() => {
    mockPrisma = {
      user: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id === testUser.id) return Promise.resolve(testUser);
          return Promise.resolve(null);
        }),
        update: jest.fn().mockResolvedValue(testUser),
      },
      userDevice: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([{ token: 'fcm_token_device_1' }]),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      notificationPreference: {
        findUnique: jest.fn().mockResolvedValue(testPrefs),
        create: jest.fn().mockResolvedValue(testPrefs),
      },
      notification: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({
            id: 'notif_canon_101',
            ...data,
            createdAt: new Date(),
          }),
        ),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(1),
        update: jest.fn(),
      },
      notificationDelivery: {
        findUnique: jest.fn(),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve({
            id: `del_${Math.random().toString(36).substring(7)}`,
            ...data,
            createdAt: new Date(),
            updatedAt: new Date(),
          }),
        ),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
        groupBy: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockImplementation(({ where, data }) =>
          Promise.resolve({ id: where.id, ...data }),
        ),
      },
    };

    mockFcm = {
      sendToUser: jest.fn().mockResolvedValue({ success: true, messageId: 'fcm_msg_101' }),
      sendToToken: jest.fn().mockResolvedValue({ success: true, messageId: 'fcm_msg_101' }),
      sendMulticast: jest.fn().mockResolvedValue(undefined),
    };

    mockSms = {
      sendSms: jest.fn().mockResolvedValue({ success: true, messageId: 'sms_msg_201' }),
    };

    mockEmail = {
      sendEmail: jest.fn().mockResolvedValue({ success: true, messageId: 'email_msg_301' }),
    };

    mockWhatsApp = {
      sendMessage: jest.fn().mockResolvedValue({ providerMessageId: 'wamid.msg_401', status: 'ACCEPTED' }),
    };

    mockQueueProducer = {
      dispatchPushNotification: jest.fn().mockResolvedValue({ jobId: 'job_push_1' }),
      dispatchSmsNotification: jest.fn().mockResolvedValue({ jobId: 'job_sms_1' }),
      dispatchEmailNotification: jest.fn().mockResolvedValue({ jobId: 'job_email_1' }),
      dispatchWhatsAppNotification: jest.fn().mockResolvedValue({ jobId: 'job_wa_1' }),
    };

    orchestrator = new NotificationOrchestratorService(
      mockPrisma,
      mockFcm as any,
      mockSms as any,
      mockEmail as any,
      mockWhatsApp as any,
      mockQueueProducer,
    );
  });

  describe('1. Canonical Event Ingestion & Multi-Channel Delivery', () => {
    it('should ingest BOOKING_CONFIRMED event and create delivery records across all enabled channels', async () => {
      const result: any = await orchestrator.publishEvent({
        eventType: 'BOOKING_CONFIRMED',
        recipientId: testUser.id,
        entityType: 'BOOKING',
        entityId: 'BK_CONF_001',
        variables: {
          bookingId: 'BK_CONF_001',
          vehicleName: 'Hyundai Creta 2024',
          pickupTime: '10:00 AM, 12 Oct',
          pickupAddress: 'Andheri West Hub',
          paymentAmount: 5500,
        },
      });

      expect(result).toBeDefined();
      expect(result.id).toBe('notif_canon_101');
      expect(result.title).toBe('Booking Confirmed!');
      expect(result.priority).toBe('HIGH');
      expect(mockPrisma.notification.create).toHaveBeenCalled();

      // Verify delivery records created: IN_APP, PUSH, SMS, WHATSAPP, EMAIL
      expect(mockPrisma.notificationDelivery.create).toHaveBeenCalledTimes(5);
      expect(result.deliveries).toHaveLength(5);

      // Verify BullMQ jobs enqueued
      expect(mockQueueProducer.dispatchPushNotification).toHaveBeenCalled();
      expect(mockQueueProducer.dispatchSmsNotification).toHaveBeenCalled();
      expect(mockQueueProducer.dispatchWhatsAppNotification).toHaveBeenCalled();
      expect(mockQueueProducer.dispatchEmailNotification).toHaveBeenCalled();
    });

    it('should generate deterministic idempotency key and avoid duplicate notification creation on replay', async () => {
      const existingNotification = {
        id: 'notif_existing_99',
        userId: testUser.id,
        title: 'Booking Confirmed!',
        body: 'Your trip is confirmed',
        idempotencyKey: 'evt_BOOKING_CONFIRMED_BK_DUP_01_usr_cust_01',
        deliveries: [{ channel: NotificationChannel.IN_APP, status: DeliveryStatus.DELIVERED }],
      };

      mockPrisma.notification.findUnique.mockResolvedValue(existingNotification);

      const result: any = await orchestrator.publishEvent({
        eventType: 'BOOKING_CONFIRMED',
        recipientId: testUser.id,
        entityType: 'BOOKING',
        entityId: 'BK_DUP_01',
        variables: { bookingId: 'BK_DUP_01', vehicleName: 'Tata Nexon' },
      });

      expect(result.id).toBe('notif_existing_99');
      expect(mockPrisma.notification.create).not.toHaveBeenCalled();
      expect(mockPrisma.notificationDelivery.create).not.toHaveBeenCalled();
      expect(mockQueueProducer.dispatchPushNotification).not.toHaveBeenCalled();
    });
  });

  describe('2. Recipient Resolution & Tenancy Isolation', () => {
    it('should return null and abort dispatch gracefully if recipient user does not exist', async () => {
      const result = await orchestrator.publishEvent({
        eventType: 'PAYMENT_CAPTURED',
        recipientId: 'usr_non_existent',
        variables: { bookingId: 'BK_NONE' },
      });

      expect(result).toBeNull();
      expect(mockPrisma.notification.create).not.toHaveBeenCalled();
    });

    it('should render correct operational variables tailored to vendor for ESCROW_HOLD_DISPUTED', async () => {
      const result: any = await orchestrator.publishEvent({
        eventType: 'ESCROW_HOLD_DISPUTED',
        recipientId: testUser.id,
        entityType: 'BOOKING',
        entityId: 'BK_DISPUTE_77',
        variables: {
          vendorName: 'Apex Fleet Hub',
          bookingId: 'BK_DISPUTE_77',
          reason: 'Active dent claim under review',
        },
      });

      expect(result.title).toBe('Escrow Settlement Hold Placed');
      expect(result.category).toBe('ESCROW');
      expect(result.priority).toBe('HIGH');
      expect(result.body).toContain('BK_DISPUTE_77');
    });
  });

  describe('3. Preference Enforcement & Channel Filtering', () => {
    it('should omit SMS, WhatsApp, and Email when user has disabled promotional channels for non-transactional event', async () => {
      mockPrisma.notificationPreference.findUnique.mockResolvedValue({
        userId: testUser.id,
        operationalPush: true,
        operationalSms: true,
        operationalEmail: true,
        operationalWhatsApp: true,
        promotionalPush: false,
        promotionalSms: false,
        promotionalEmail: false,
        promotionalWhatsApp: false,
      });

      await orchestrator.publishEvent({
        eventType: 'BOOKING_CREATED',
        recipientId: testUser.id,
        variables: { bookingId: 'BK_PROMO_1' },
        isTransactional: false, // Promotional / non-critical
      });

      // When isTransactional=false and promotional flags are false, only IN_APP should be created
      expect(mockPrisma.notificationDelivery.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            channel: NotificationChannel.IN_APP,
          }),
        }),
      );
      expect(mockQueueProducer.dispatchSmsNotification).not.toHaveBeenCalled();
      expect(mockQueueProducer.dispatchEmailNotification).not.toHaveBeenCalled();
      expect(mockQueueProducer.dispatchWhatsAppNotification).not.toHaveBeenCalled();
    });
  });

  describe('4. Direct Channel Execution & Delivery Tracking', () => {
    it('should update delivery status to DELIVERED and persist providerMessageId on successful SMS dispatch', async () => {
      const result = await orchestrator.executeSmsDelivery(
        'del_sms_01',
        '+919876543210',
        'DriveGo: Booking confirmed',
      );

      expect(result.success).toBe(true);
      expect(mockPrisma.notificationDelivery.update).toHaveBeenCalledWith({
        where: { id: 'del_sms_01' },
        data: expect.objectContaining({
          status: DeliveryStatus.DELIVERED,
          providerMessageId: 'sms_msg_201',
        }),
      });
    });

    it('should update delivery status to FAILED and record error when provider fails', async () => {
      mockSms.sendSms.mockResolvedValueOnce({
        success: false,
        error: 'Carrier network unreachable',
      });

      const result = await orchestrator.executeSmsDelivery(
        'del_sms_02',
        '+919876543210',
        'DriveGo: Booking confirmed',
      );

      expect(result.success).toBe(false);
      expect(mockPrisma.notificationDelivery.update).toHaveBeenCalledWith({
        where: { id: 'del_sms_02' },
        data: expect.objectContaining({
          status: DeliveryStatus.FAILED,
          lastError: 'Carrier network unreachable',
        }),
      });
    });

    it('should mark delivery as DEAD_LETTER when maximum retries are exhausted', async () => {
      mockPrisma.notificationDelivery.findUnique.mockResolvedValue({
        id: 'del_fail_03',
        attemptCount: 2,
        maxRetries: 3,
      });

      mockEmail.sendEmail.mockRejectedValueOnce(new Error('SMTP Auth Timeout'));

      await expect(
        orchestrator.executeEmailDelivery(
          'del_fail_03',
          'user@example.com',
          'Trip Confirmed',
          '<p>Hello</p>',
        ),
      ).rejects.toThrow('SMTP Auth Timeout');

      expect(mockPrisma.notificationDelivery.update).toHaveBeenCalledWith({
        where: { id: 'del_fail_03' },
        data: expect.objectContaining({
          status: DeliveryStatus.DEAD_LETTER,
          attemptCount: 3,
          lastError: 'SMTP Auth Timeout',
        }),
      });
    });
  });

  describe('5. Admin Governance & Observability', () => {
    it('should fetch deliveries with filter support and pagination', async () => {
      mockPrisma.notificationDelivery.findMany.mockResolvedValue([
        { id: 'del_1', channel: NotificationChannel.PUSH, status: DeliveryStatus.DELIVERED },
      ]);
      mockPrisma.notificationDelivery.count.mockResolvedValue(1);

      const result = await orchestrator.getDeliveries({
        page: 1,
        limit: 10,
        channel: NotificationChannel.PUSH,
        status: DeliveryStatus.DELIVERED,
      });

      expect(result.total).toBe(1);
      expect(result.items).toHaveLength(1);
      expect(mockPrisma.notificationDelivery.findMany).toHaveBeenCalled();
    });

    it('should aggregate delivery statistics with percentage rates', async () => {
      mockPrisma.notificationDelivery.count
        .mockResolvedValueOnce(100) // total
        .mockResolvedValueOnce(95)  // delivered
        .mockResolvedValueOnce(3)   // failed
        .mockResolvedValueOnce(2)   // deadLetter
        .mockResolvedValueOnce(0);  // queued

      const stats = await orchestrator.getDeliveryStats();

      expect(stats.overview.total).toBe(100);
      expect(stats.overview.delivered).toBe(95);
      expect(stats.overview.deliveryRate).toBe('95.0%');
    });

    it('should allow admin to retry a failed delivery and reset status to QUEUED', async () => {
      mockPrisma.notificationDelivery.findUnique.mockResolvedValue({
        id: 'del_retry_01',
        channel: NotificationChannel.SMS,
        status: DeliveryStatus.FAILED,
        notification: {
          userId: testUser.id,
          eventType: 'BOOKING_CONFIRMED',
          entityId: 'BK_RETRY_1',
          metadata: { vehicleName: 'Kia Seltos' },
        },
      });

      const res = await orchestrator.retryDelivery('del_retry_01');

      expect(res.success).toBe(true);
      expect(res.status).toBe('QUEUED');
      expect(mockPrisma.notificationDelivery.update).toHaveBeenCalledWith({
        where: { id: 'del_retry_01' },
        data: expect.objectContaining({
          status: DeliveryStatus.QUEUED,
          lastError: null,
        }),
      });
    });
  });
});
