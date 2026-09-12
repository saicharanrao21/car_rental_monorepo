import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
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

  describe('Role-Based Access Control (@Roles guards)', () => {
    let customerToken: string;
    let vendorToken: string;
    let adminToken: string;

    beforeAll(() => {
      const configService = app.get(ConfigService);
      const secret =
        configService.get<string>('JWT_ACCESS_SECRET') ||
        process.env.JWT_ACCESS_SECRET ||
        'test_jwt_access_secret_min_32_chars_long!';

      const jwtService = new JwtService({ secret });

      customerToken = jwtService.sign({
        userId: 'cust-uuid-101',
        role: Role.CUSTOMER,
      });

      vendorToken = jwtService.sign({
        userId: 'vendor-uuid-202',
        role: Role.VENDOR,
      });

      adminToken = jwtService.sign({
        userId: 'admin-uuid-303',
        role: Role.ADMIN,
      });
    });

    it('POST /api/v1/fleet/car-123/immobilize rejects CUSTOMER with 403 Forbidden', () => {
      return request(app.getHttpServer())
        .post('/api/v1/fleet/car-123/immobilize')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({ reason: 'Unauthorized customer probe' })
        .expect(403);
    });

    it('POST /api/v1/operations/workflows rejects CUSTOMER with 403 Forbidden', () => {
      return request(app.getHttpServer())
        .post('/api/v1/operations/workflows')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          name: 'Customer probe workflow',
          triggerEvent: 'CUSTOM_EVENT',
          steps: [],
          startStepId: 'step_1',
        })
        .expect(403);
    });

    it('POST /api/v1/operations/workflows rejects VENDOR with 403 Forbidden', () => {
      return request(app.getHttpServer())
        .post('/api/v1/operations/workflows')
        .set('Authorization', `Bearer ${vendorToken}`)
        .send({
          name: 'Vendor probe workflow',
          triggerEvent: 'CUSTOM_EVENT',
          steps: [],
          startStepId: 'step_1',
        })
        .expect(403);
    });

    it('POST /api/v1/fleet/car-123/immobilize allows VENDOR through auth guards (fails with 503 gateway error, not 401/403)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/fleet/car-123/immobilize')
        .set('Authorization', `Bearer ${vendorToken}`)
        .send({ reason: 'Authorized vendor command' });

      // Passes JwtAuthGuard & RolesGuard. Fails specifically on hardware gateway lookup (503), not auth (401/403).
      expect(res.status).not.toBe(401);
      expect(res.status).not.toBe(403);
      expect(res.status).toBe(503);
      expect(res.body.message).toMatch(/telematics IoT gateway|hardware gateway/i);
    });

    it('POST /api/v1/fleet/car-123/immobilize allows ADMIN through auth guards (fails with 503 gateway error, not 401/403)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/fleet/car-123/immobilize')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Authorized admin command' });

      expect(res.status).not.toBe(401);
      expect(res.status).not.toBe(403);
      expect(res.status).toBe(503);
      expect(res.body.message).toMatch(/telematics IoT gateway|hardware gateway/i);
    });

    it('POST /api/v1/operations/workflows allows ADMIN and executes successfully (201 Created)', () => {
      return request(app.getHttpServer())
        .post('/api/v1/operations/workflows')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          name: 'Admin Enterprise Workflow',
          description: 'Automated fleet reconciliation workflow',
          triggerEvent: 'FLEET_MAINTENANCE_TRIGGERED',
          steps: [
            {
              stepId: 'step_1',
              name: 'Notify Fleet Manager',
              actionType: 'SEND_NOTIFICATION',
              config: {},
            },
          ],
          startStepId: 'step_1',
        })
        .expect(201)
        .expect((res) => {
          expect(res.body).toHaveProperty('workflowId');
          expect(res.body.name).toBe('Admin Enterprise Workflow');
          expect(res.body.status).toBe('ACTIVE');
        });
    });
  });
});
