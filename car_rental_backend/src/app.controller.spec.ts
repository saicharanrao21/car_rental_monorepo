import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { PrismaService } from './prisma/prisma.service';
import { REDIS_CLIENT } from './redis/redis.module';

describe('AppController', () => {
  let appController: AppController;

  const mockPrismaService = {
    $queryRaw: jest.fn().mockResolvedValue([{ '1': 1 }]),
  };

  const mockRedisClient = {
    ping: jest.fn().mockResolvedValue('PONG'),
  };

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
        {
          provide: REDIS_CLIENT,
          useValue: mockRedisClient,
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('health', () => {
    it('should return health status ok', async () => {
      const res = await appController.getHealth();
      expect(res).toEqual({
        status: 'ok',
        db: true,
        redis: true,
      });
    });

    it('should return liveness status alive', () => {
      const res = appController.getLiveness();
      expect(res.status).toBe('alive');
      expect(typeof res.uptime).toBe('number');
      expect(typeof res.timestamp).toBe('string');
    });

    it('should return readiness status ready when database is available', async () => {
      const res = await appController.getReadiness();
      expect(res.status).toBe('ready');
      expect(res.db).toBe(true);
      expect(res.redis).toBe(true);
    });

    it('should reject readiness with 503 when database is unavailable', async () => {
      mockPrismaService.$queryRaw.mockRejectedValueOnce(
        new Error('Connection terminated'),
      );
      await expect(appController.getReadiness()).rejects.toThrow();
    });
  });
});
