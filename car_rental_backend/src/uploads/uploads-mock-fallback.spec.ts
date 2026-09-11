import { ConfigService } from '@nestjs/config';
import { UploadsService } from './uploads.service';
import { UploadsController } from './uploads.controller';

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

describe('UploadsController Security Hardening', () => {
  let controller: UploadsController;
  const originalEnv = process.env.NODE_ENV;

  beforeEach(() => {
    const mockUploadsService = {} as any;
    controller = new UploadsController(mockUploadsService);
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
  });

  it('should reject mockUpload in production environment', async () => {
    process.env.NODE_ENV = 'production';
    const req = { pipe: jest.fn(), on: jest.fn() };
    const res = { status: jest.fn().mockReturnThis(), send: jest.fn() };

    await expect(
      controller.mockUpload('profile-photo', 'usr_123', 'avatar.jpg', req, res),
    ).rejects.toThrow(/Mock upload endpoint is disabled in production/);
  });

  it('should reject serveMockFile in production environment', async () => {
    process.env.NODE_ENV = 'production';
    const res = { setHeader: jest.fn() };

    await expect(
      controller.serveMockFile('profile-photo', 'usr_123', 'avatar.jpg', res),
    ).rejects.toThrow(/Mock file serving endpoint is disabled in production/);
  });

  it('should reject path traversal attempts in mockUpload and serveMockFile', async () => {
    process.env.NODE_ENV = 'development';
    const req = { pipe: jest.fn(), on: jest.fn() };
    const res = { status: jest.fn().mockReturnThis(), send: jest.fn(), setHeader: jest.fn() };

    // Path traversal in fileType or userId
    await expect(
      controller.mockUpload('../../../etc', 'passwd', 'file.txt', req, res),
    ).rejects.toThrow();

    await expect(
      controller.serveMockFile('../../../etc', 'passwd', 'file.txt', res),
    ).rejects.toThrow();
  });
});
