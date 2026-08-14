import { ConfigService } from '@nestjs/config';
import { Msg91SmsProvider } from './msg91-sms-provider.service';

describe('Msg91SmsProvider (Phase 2A)', () => {
  let provider: Msg91SmsProvider;
  let configService: ConfigService;
  let originalFetch: typeof global.fetch;

  const validConfig = {
    MSG91_AUTH_KEY: 'test_real_auth_key_123456',
    MSG91_TEMPLATE_ID: 'dlt_template_id_999',
    MSG91_SENDER_ID: 'DRIVGO',
    NODE_ENV: 'production',
  };

  beforeAll(() => {
    originalFetch = global.fetch;
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  beforeEach(() => {
    configService = new ConfigService(validConfig);
    provider = new Msg91SmsProvider(configService);
  });

  it('should format Indian 10-digit mobile number with 91 prefix and send OTP successfully', async () => {
    const mockFetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: () =>
        Promise.resolve(
          JSON.stringify({ type: 'success', message: 'OTP sent successfully' }),
        ),
    });
    global.fetch = mockFetch;

    await expect(
      provider.sendSms(
        '9876543210',
        'Your DriveGo OTP is 123456. It is valid for 5 minutes.',
        '123456',
      ),
    ).resolves.not.toThrow();

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const calledUrl = mockFetch.mock.calls[0][0];
    const calledOpts = mockFetch.mock.calls[0][1];

    expect(calledUrl).toContain('mobile=919876543210');
    expect(calledUrl).toContain('template_id=dlt_template_id_999');
    expect(calledUrl).toContain('otp=123456');
    expect(calledOpts.headers.authkey).toBe('test_real_auth_key_123456');
  });

  it('should throw error when MSG91 returns non-200 HTTP status', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: () =>
        Promise.resolve(
          JSON.stringify({ type: 'error', message: 'Authentication failed' }),
        ),
    });

    await expect(
      provider.sendSms('9876543210', 'OTP is 123456', '123456'),
    ).rejects.toThrow(/MSG91 gateway responded with HTTP 401/);
  });

  it('should throw error when MSG91 returns 200 with type="error"', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: () =>
        Promise.resolve(
          JSON.stringify({ type: 'error', message: 'Invalid mobile number' }),
        ),
    });

    await expect(
      provider.sendSms('9876543210', 'OTP is 123456', '123456'),
    ).rejects.toThrow(/MSG91 gateway rejected dispatch: Invalid mobile number/);
  });

  it('should throw safe error on network failure without leaking credentials', async () => {
    global.fetch = jest
      .fn()
      .mockRejectedValue(new Error('Connection refused to control.msg91.com'));

    try {
      await provider.sendSms('9876543210', 'OTP is 123456', '123456');
      fail('Expected error to be thrown');
    } catch (err: any) {
      expect(err.message).toBe(
        'SMS Gateway network dispatch failure. Please try again.',
      );
      expect(err.message).not.toContain('test_real_auth_key_123456');
    }
  });

  it('should throw timeout error when request exceeds timeout limit', async () => {
    const timeoutError = new Error('The operation was aborted');
    timeoutError.name = 'TimeoutError';
    global.fetch = jest.fn().mockRejectedValue(timeoutError);

    await expect(
      provider.sendSms('9876543210', 'OTP is 123456', '123456'),
    ).rejects.toThrow(/SMS Gateway request timed out/);
  });

  it('should throw fatal error on boot in production if required MSG91 credentials are missing', () => {
    const badConfig = new ConfigService({
      NODE_ENV: 'production',
      MSG91_AUTH_KEY: '',
    });

    expect(() => new Msg91SmsProvider(badConfig)).toThrow(
      /MSG91_AUTH_KEY and MSG91_TEMPLATE_ID are required when using Msg91SmsProvider in production/,
    );
  });
});
