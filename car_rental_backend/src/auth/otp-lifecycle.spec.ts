import { HttpException, HttpStatus } from '@nestjs/common';
import { OtpService } from './otp.service';
import * as bcrypt from 'bcrypt';

describe('OTP Lifecycle & Security Hardening (Phase 2A)', () => {
  let otpService: OtpService;
  let mockPrisma: any;
  let mockSmsProvider: any;
  let mockRedis: any;

  // In-memory mock database store for OtpRequest
  let otpDatabase: any[] = [];
  let nextId = 1;

  beforeEach(() => {
    otpDatabase = [];
    nextId = 1;

    mockPrisma = {
      otpRequest: {
        create: jest.fn().mockImplementation(({ data }) => {
          const record = {
            id: `otp-${nextId++}`,
            phone: data.phone,
            otpHash: data.otpHash,
            expiresAt: data.expiresAt,
            verified: false,
            attemptCount: 0,
            createdAt: new Date(),
          };
          otpDatabase.push(record);
          return Promise.resolve(record);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const record = otpDatabase.find((r) => r.id === where.id);
          if (record) {
            if (data.verified !== undefined) record.verified = data.verified;
            if (data.expiresAt !== undefined) record.expiresAt = data.expiresAt;
            if (data.attemptCount?.increment)
              record.attemptCount += data.attemptCount.increment;
          }
          return Promise.resolve(record);
        }),
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          let count = 0;
          otpDatabase.forEach((record) => {
            if (
              record.phone === where.phone &&
              (!where.verified || record.verified === where.verified)
            ) {
              if (data.expiresAt !== undefined)
                record.expiresAt = data.expiresAt;
              count++;
            }
          });
          return Promise.resolve({ count });
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          const matching = otpDatabase
            .filter(
              (r) =>
                r.phone === where.phone &&
                (where.verified === undefined || r.verified === where.verified),
            )
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
          return Promise.resolve(matching[0] || null);
        }),
      },
    };

    mockSmsProvider = {
      sendSms: jest.fn().mockResolvedValue(undefined),
    };

    mockRedis = {
      store: new Map<string, string>(),
      get: jest
        .fn()
        .mockImplementation((k: string) =>
          Promise.resolve(mockRedis.store.get(k) || null),
        ),
      set: jest.fn().mockImplementation((k: string, v: string) => {
        mockRedis.store.set(k, v);
        return Promise.resolve('OK');
      }),
      del: jest.fn().mockImplementation((k: string) => {
        mockRedis.store.delete(k);
        return Promise.resolve(1);
      }),
    };

    otpService = new OtpService(mockPrisma, mockSmsProvider, mockRedis);
  });

  it('should invalidate previous active OTPs when a new OTP is issued', async () => {
    // 1st OTP
    await otpService.sendOtp('+919876543210');
    expect(otpDatabase.length).toBe(1);
    const firstOtpId = otpDatabase[0].id;
    const firstOtpExpiresAt = otpDatabase[0].expiresAt;
    expect(firstOtpExpiresAt.getTime()).toBeGreaterThan(Date.now());

    // 2nd OTP for the same phone (clear redis cooldown for test simulation)
    mockRedis.store.clear();
    await otpService.sendOtp('+919876543210');
    expect(otpDatabase.length).toBe(2);

    // Verify 1st OTP was expired
    const firstOtpRecord = otpDatabase.find((r) => r.id === firstOtpId);
    expect(firstOtpRecord.expiresAt.getTime()).toBeLessThan(Date.now());

    // Verify 2nd OTP is active
    const secondOtpRecord = otpDatabase[1];
    expect(secondOtpRecord.expiresAt.getTime()).toBeGreaterThan(Date.now());
  });

  it('should successfully verify the newest active OTP and invalidate it for reuse', async () => {
    // Send OTP
    await otpService.sendOtp('+919876543210');
    const createdRecord = otpDatabase[0];

    // Intercept generated OTP code from the SMS provider invocation
    const calledMessage = mockSmsProvider.sendSms.mock.calls[0][1];
    const otpCode = calledMessage.match(/\b\d{6}\b/)[0];

    // Verification attempt with correct OTP code
    const isVerified = await otpService.verifyOtp('+919876543210', otpCode);
    expect(isVerified).toBe(true);
    expect(createdRecord.verified).toBe(true);

    // Attempting to reuse the same OTP must fail
    await expect(
      otpService.verifyOtp('+919876543210', otpCode),
    ).rejects.toThrow(/No OTP request found for this phone number/);
  });

  it('should reject previous OTP after a newer OTP has been issued', async () => {
    // 1st OTP
    await otpService.sendOtp('+919876543210');
    const firstCode =
      mockSmsProvider.sendSms.mock.calls[0][1].match(/\b\d{6}\b/)[0];

    // 2nd OTP
    mockRedis.store.clear();
    await otpService.sendOtp('+919876543210');
    const secondCode =
      mockSmsProvider.sendSms.mock.calls[1][1].match(/\b\d{6}\b/)[0];

    // Trying first OTP must fail with invalid/expired
    await expect(
      otpService.verifyOtp('+919876543210', firstCode),
    ).rejects.toThrow(HttpException);

    // Second OTP must verify successfully
    const isVerified = await otpService.verifyOtp('+919876543210', secondCode);
    expect(isVerified).toBe(true);
  });

  it('should reject expired OTP', async () => {
    await otpService.sendOtp('+919876543210');
    const record = otpDatabase[0];
    const otpCode =
      mockSmsProvider.sendSms.mock.calls[0][1].match(/\b\d{6}\b/)[0];

    // Fast-forward time so OTP expires
    record.expiresAt = new Date(Date.now() - 10000);

    await expect(
      otpService.verifyOtp('+919876543210', otpCode),
    ).rejects.toThrow(/OTP has expired. Please request a new one./);
  });

  it('should invalidate OTP record and throw BAD_GATEWAY if SMS dispatch fails', async () => {
    mockSmsProvider.sendSms.mockRejectedValueOnce(
      new Error('Gateway connection failed'),
    );

    await expect(otpService.sendOtp('+919876543210')).rejects.toThrow(
      new HttpException(
        'Failed to deliver OTP via SMS. Please try again.',
        HttpStatus.BAD_GATEWAY,
      ),
    );

    // Check that created record was immediately expired
    expect(otpDatabase.length).toBe(1);
    expect(otpDatabase[0].expiresAt.getTime()).toBeLessThan(Date.now());
  });
});
