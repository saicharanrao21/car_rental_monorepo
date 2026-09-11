import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('AppController & Security Guards (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.REDIS_USE_MOCK = 'true';
    process.env.JWT_ACCESS_SECRET = 'test_jwt_access_secret_min_32_chars_long!';
    process.env.JWT_REFRESH_SECRET = 'test_jwt_refresh_secret_min_32_chars_long!';
    process.env.BANK_ENCRYPTION_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });

  it('GET / should return API status', () => {
    return request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect((res) => {
        expect(res.body.name).toBe('DriveGo Car Rental API');
        expect(res.body.status).toBe('online');
      });
  });

  it('GET /health should respond with health status', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect((res) => {
        expect(res.body).toHaveProperty('status');
        expect(res.body).toHaveProperty('db');
        expect(res.body).toHaveProperty('redis');
      });
  });

  it('GET /api/v1/fleet/kpis should reject unauthenticated request with 401', () => {
    return request(app.getHttpServer())
      .get('/api/v1/fleet/kpis')
      .expect(401);
  });

  it('POST /api/v1/fleet/car-123/immobilize should reject unauthenticated request with 401', () => {
    return request(app.getHttpServer())
      .post('/api/v1/fleet/car-123/immobilize')
      .send({ reason: 'testing security' })
      .expect(401);
  });

  it('GET /api/v1/operations/workflows should reject unauthenticated request with 401', () => {
    return request(app.getHttpServer())
      .get('/api/v1/operations/workflows')
      .expect(401);
  });

  it('POST /marketplace/checkout/session should reject unauthenticated request with 401', () => {
    return request(app.getHttpServer())
      .post('/marketplace/checkout/session')
      .send({ quoteId: 'quote_test' })
      .expect(401);
  });
});
