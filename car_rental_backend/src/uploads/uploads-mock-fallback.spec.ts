import { ConfigService } from '@nestjs/config';
import { UploadsService } from './uploads.service';

describe('UploadsService Mock Fallback Hardening (Phase 2B)', () => {
  it('should throw fatal error if R2_USE_MOCK is true in production', () => {
    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'production';
        if (key === 'R2_USE_MOCK') return 'true';
        return '';
      }),
    } as unknown as ConfigService;

    expect(() => new UploadsService(configService)).toThrow(
      /R2_USE_MOCK is set to true, but NODE_ENV is production/,
    );
  });

  it('should allow mock mode in development environment if R2_USE_MOCK is true', () => {
    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'NODE_ENV') return 'development';
        if (key === 'R2_USE_MOCK') return 'true';
        return '';
      }),
    } as unknown as ConfigService;

    const service = new UploadsService(configService);
    expect(service).toBeDefined();
  });
});
