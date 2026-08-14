import { ConfigService } from '@nestjs/config';
import { Msg91SmsProvider } from './msg91-sms-provider.service';
import { MockSmsProvider, SmsProviderService } from './sms-provider.service';

describe('SMS Provider Selection (Phase 2A)', () => {
  function createSmsProvider(
    config: Record<string, string>,
  ): SmsProviderService {
    const configService = new ConfigService(config);
    const nodeEnv = configService.get<string>('NODE_ENV');
    const smsProvider = configService.get<string>('SMS_PROVIDER');

    if (nodeEnv === 'production' || smsProvider === 'msg91') {
      return new Msg91SmsProvider(configService);
    }
    return new MockSmsProvider();
  }

  it('should select Msg91SmsProvider when NODE_ENV is production', () => {
    const provider = createSmsProvider({
      NODE_ENV: 'production',
      MSG91_AUTH_KEY: 'auth_key_123',
      MSG91_TEMPLATE_ID: 'template_123',
    });

    expect(provider).toBeInstanceOf(Msg91SmsProvider);
  });

  it('should select Msg91SmsProvider when SMS_PROVIDER is explicitly set to msg91 in staging/dev', () => {
    const provider = createSmsProvider({
      NODE_ENV: 'development',
      SMS_PROVIDER: 'msg91',
      MSG91_AUTH_KEY: 'auth_key_123',
      MSG91_TEMPLATE_ID: 'template_123',
    });

    expect(provider).toBeInstanceOf(Msg91SmsProvider);
  });

  it('should select MockSmsProvider in development mode when SMS_PROVIDER is mock or not set', () => {
    const provider = createSmsProvider({
      NODE_ENV: 'development',
      SMS_PROVIDER: 'mock',
    });

    expect(provider).toBeInstanceOf(MockSmsProvider);
  });
});
