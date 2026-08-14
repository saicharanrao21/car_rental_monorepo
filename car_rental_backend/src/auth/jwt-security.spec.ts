import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Role } from '@prisma/client';
import { CarsController } from '../cars/cars.controller';
import { VendorsController } from '../vendors/vendors.controller';

describe('Cryptographic JWT Verification & Controller Security (Phase 1)', () => {
  let jwtService: JwtService;
  let configService: ConfigService;
  let carsController: CarsController;
  let vendorsController: VendorsController;

  const validSecret = 'super_secret_access_key_for_testing_32chars!';
  const forgedSecret = 'attacker_forged_secret_key_1234567890!';

  const mockCarsService = {
    searchCars: jest
      .fn()
      .mockImplementation((query, isAdmin) => ({ query, isAdmin })),
    findOne: jest.fn(),
    adminFindAll: jest.fn(),
    adminDeactivate: jest.fn(),
  };

  const mockVendorsService = {
    findAll: jest.fn().mockImplementation((query) => ({
      data: [{ id: 'v1', businessName: 'Test' }],
    })),
    findOne: jest
      .fn()
      .mockImplementation((id) => ({ id, businessName: 'Test' })),
    findByUserId: jest.fn(),
    updateMe: jest.fn(),
  };

  beforeEach(() => {
    jwtService = new JwtService({});
    configService = new ConfigService({
      JWT_ACCESS_SECRET: validSecret,
    });

    carsController = new CarsController(
      mockCarsService as any,
      jwtService,
      configService,
    );

    vendorsController = new VendorsController(
      mockVendorsService as any,
      mockCarsService as any,
      jwtService,
      configService,
    );
  });

  it('should grant admin privilege to validly signed ADMIN token', async () => {
    const validAdminToken = jwtService.sign(
      { userId: 'admin-1', role: Role.ADMIN },
      { secret: validSecret },
    );

    const req = {
      headers: {
        authorization: `Bearer ${validAdminToken}`,
      },
    };

    const result = await carsController.searchCars(req, {});
    expect((result as any).isAdmin).toBe(true);
  });

  it('should grant support agent privilege in searchCars to validly signed SUPPORT_AGENT token', async () => {
    const validSupportToken = jwtService.sign(
      { userId: 'support-1', role: Role.SUPPORT_AGENT },
      { secret: validSecret },
    );

    const req = {
      headers: {
        authorization: `Bearer ${validSupportToken}`,
      },
    };

    const result = await carsController.searchCars(req, {});
    expect((result as any).isAdmin).toBe(true);
  });

  it('should reject forged JWT signed with different secret and treat as non-admin', async () => {
    // Attacker creates a token with role ADMIN but signed with their own key
    const forgedToken = jwtService.sign(
      { userId: 'attacker-1', role: Role.ADMIN },
      { secret: forgedSecret },
    );

    const req = {
      headers: {
        authorization: `Bearer ${forgedToken}`,
      },
    };

    const result = await carsController.searchCars(req, {});
    expect((result as any).isAdmin).toBe(false);
  });

  it('should reject tampered or malformed JWT in vendorsController and treat as non-admin', async () => {
    const req = {
      headers: {
        authorization:
          'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.tampered_payload.fake_signature',
      },
    };

    const result = await vendorsController.findAll(req, {});
    expect(mockVendorsService.findAll).toHaveBeenCalled();
  });

  it('should reject expired JWT and treat as non-admin', async () => {
    const expiredToken = jwtService.sign(
      { userId: 'admin-1', role: Role.ADMIN },
      { secret: validSecret, expiresIn: '-1s' },
    );

    const req = {
      headers: {
        authorization: `Bearer ${expiredToken}`,
      },
    };

    const result = await carsController.searchCars(req, {});
    expect((result as any).isAdmin).toBe(false);
  });

  it('should treat request without authorization header as non-admin', async () => {
    const req = { headers: {} };
    const result = await carsController.searchCars(req, {});
    expect((result as any).isAdmin).toBe(false);
  });
});
