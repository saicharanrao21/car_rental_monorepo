import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

import { json, urlencoded } from 'express';
import * as crypto from 'crypto';

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

    app = moduleFixture.createNestApplication({ bodyParser: false });
    app.use(
      json({
        verify: (req: any, res, buf) => {
          if (buf && buf.length) {
            req.rawBody = buf.toString('utf8');
          }
        },
      }),
    );
    app.use(urlencoded({ extended: true }));
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

      console.log('CAPTURED_503_RESPONSE_BODY:', JSON.stringify(res.body));

      // Passes JwtAuthGuard & RolesGuard. Fails specifically on hardware gateway lookup (503), not auth (401/403).
      expect(res.status).not.toBe(401);
      expect(res.status).not.toBe(403);
      expect(res.status).toBe(503);
      expect(res.body.message).toMatch(/telematics|hardware gateway/i);
    });

    it('POST /api/v1/fleet/car-123/immobilize allows ADMIN through auth guards (fails with 503 gateway error, not 401/403)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/fleet/car-123/immobilize')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Authorized admin command' });

      expect(res.status).not.toBe(401);
      expect(res.status).not.toBe(403);
      expect(res.status).toBe(503);
      expect(res.body.message).toMatch(/telematics|hardware gateway/i);
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

  describe('Payments Webhook Controller HTTP Boundary (e2e)', () => {
    it('POST /payments/webhook rejects request without signature with 400 Bad Request', () => {
      return request(app.getHttpServer())
        .post('/payments/webhook')
        .send({ event: 'payment.captured' })
        .expect(400);
    });

    it('POST /payments/webhook rejects forged signature with 400 Bad Request', () => {
      return request(app.getHttpServer())
        .post('/payments/webhook')
        .set('x-razorpay-signature', 'forged_invalid_signature_hex_12345')
        .send({ event: 'payment.captured' })
        .expect(400);
    });

    it('POST /payments/webhook processes valid signature through HTTP pipeline with 200/201', async () => {
      const configService = app.get(ConfigService);
      const secret =
        configService.get<string>('RAZORPAY_WEBHOOK_SECRET') ||
        'placeholderWebhookSecret';

      const payloadObj = {
        event: 'payment.captured',
        id: `evt_http_test_${Date.now()}`,
        payload: {
          payment: {
            entity: {
              id: `pay_http_${Date.now()}`,
              order_id: `order_http_fake_${Date.now()}`,
              amount: 350000,
              currency: 'INR',
              status: 'captured',
            },
          },
        },
      };
      const rawPayload = JSON.stringify(payloadObj);

      const validSig = crypto
        .createHmac('sha256', secret)
        .update(rawPayload)
        .digest('hex');

      const res = await request(app.getHttpServer())
        .post('/payments/webhook')
        .set('Content-Type', 'application/json')
        .set('x-razorpay-signature', validSig)
        .send(rawPayload);

      expect(res.status).toBeLessThan(400);
      expect(res.body).toHaveProperty('received', true);
    });
  });

  describe('Admin Fleet Controller HTTP Boundary (e2e)', () => {
    let customerToken: string;

    beforeAll(() => {
      const configService = app.get(ConfigService);
      const secret =
        configService.get<string>('JWT_ACCESS_SECRET') ||
        process.env.JWT_ACCESS_SECRET ||
        'test_jwt_access_secret_min_32_chars_long!';

      const jwtService = new JwtService({ secret });
      customerToken = jwtService.sign({
        userId: 'cust-uuid-404',
        role: Role.CUSTOMER,
      });
    });

    it('POST /admin/fleet/car-123/suspend rejects unauthenticated request with 401 Unauthorized', () => {
      return request(app.getHttpServer())
        .post('/admin/fleet/car-123/suspend')
        .send({ reason: 'Suspension probe' })
        .expect(401);
    });

    it('POST /admin/fleet/car-123/suspend rejects CUSTOMER role with 403 Forbidden', () => {
      return request(app.getHttpServer())
        .post('/admin/fleet/car-123/suspend')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({ reason: 'Unauthorized customer mutation probe' })
        .expect(403);
    });

    it('GET /admin/fleet rejects unauthenticated request with 401 Unauthorized', () => {
      return request(app.getHttpServer())
        .get('/admin/fleet')
        .expect(401);
    });
  });
});
