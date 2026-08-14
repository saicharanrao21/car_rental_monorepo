import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { OtpService } from './otp.service';
import { BankEncryptionService } from '../common/bank-encryption.service';
import { Role } from '@prisma/client';
import { HttpException, HttpStatus } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('Phase 4E: Support Agent Login Enablement', () => {
  let authService: AuthService;
  let prisma: any;
  let jwtService: any;

  const validPassword = 'SecurePassword123!';
  const passwordHash = bcrypt.hashSync(validPassword, 10);

  beforeEach(async () => {
    prisma = {
      user: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
      },
      refreshToken: {
        create: jest.fn().mockResolvedValue({ id: 'token-rec-1' }),
        update: jest.fn().mockResolvedValue({}),
      },
    };

    jwtService = {
      sign: jest.fn().mockReturnValue('jwt-mock-token'),
      signAsync: jest.fn().mockResolvedValue('jwt-mock-token'),
      verify: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwtService },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('30d') } },
        { provide: OtpService, useValue: {} },
        { provide: BankEncryptionService, useValue: {} },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
  });

  it('1. should allow Role.ADMIN to login via adminLogin', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'admin-1',
      email: 'admin@drivego.in',
      role: Role.ADMIN,
      passwordHash,
      banned: false,
    });

    const result = await authService.adminLogin(
      'admin@drivego.in',
      validPassword,
    );

    expect(result.user.role).toBe(Role.ADMIN);
    expect(result.accessToken).toBe('jwt-mock-token');
    expect(jwtService.sign).toHaveBeenCalledWith(
      expect.objectContaining({ role: Role.ADMIN }),
      expect.any(Object),
    );
  });

  it('2. should allow Role.SUPPORT_AGENT to login via adminLogin', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'support-1',
      email: 'support@drivego.in',
      role: Role.SUPPORT_AGENT,
      passwordHash,
      banned: false,
    });

    const result = await authService.adminLogin(
      'support@drivego.in',
      validPassword,
    );

    expect(result.user.role).toBe(Role.SUPPORT_AGENT);
    expect(result.accessToken).toBe('jwt-mock-token');
    expect(jwtService.sign).toHaveBeenCalledWith(
      expect.objectContaining({ role: Role.SUPPORT_AGENT }),
      expect.any(Object),
    );
  });

  it('3. should reject CUSTOMER or VENDOR attempting to login via adminLogin', async () => {
    // When a non-staff user attempts admin login, findFirst with role in [ADMIN, SUPPORT_AGENT] returns null
    prisma.user.findFirst.mockResolvedValue(null);

    await expect(
      authService.adminLogin('customer@drivego.in', validPassword),
    ).rejects.toThrow(HttpException);
  });

  it('4. should reject banned SUPPORT_AGENT from authenticating', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'support-banned',
      email: 'banned_support@drivego.in',
      role: Role.SUPPORT_AGENT,
      passwordHash,
      banned: true,
    });

    await expect(
      authService.adminLogin('banned_support@drivego.in', validPassword),
    ).rejects.toThrow(new HttpException('This account has been banned.', HttpStatus.FORBIDDEN));
  });

  describe('SEC-02: Support Agent RBAC Mutation Lockdown on AdminVendorsController', () => {
    let rolesGuard: any;
    let reflector: any;

    beforeEach(() => {
      reflector = {
        getAllAndOverride: jest.fn(),
      };
      const { RolesGuard } = require('./guards/roles.guard');
      rolesGuard = new RolesGuard(reflector);
    });

    function createMockContext(userRole: Role, handlerRoles?: Role[], classRoles?: Role[]) {
      reflector.getAllAndOverride.mockImplementation((key: string, targets: any[]) => {
        // If handler has explicit roles, it overrides class
        if (handlerRoles !== undefined) return handlerRoles;
        return classRoles;
      });

      return {
        switchToHttp: () => ({
          getRequest: () => ({
            user: { userId: 'test-user', role: userRole },
          }),
        }),
        getHandler: () => ({}),
        getClass: () => ({}),
      };
    }

    it('5. should allow SUPPORT_AGENT on vendor read endpoints (class-level @Roles(ADMIN, SUPPORT_AGENT))', () => {
      // GET :vendorId/documents -> inherits class roles
      const ctx = createMockContext(Role.SUPPORT_AGENT, undefined, [Role.ADMIN, Role.SUPPORT_AGENT]);
      expect(rolesGuard.canActivate(ctx)).toBe(true);
    });

    it('6. should DENY SUPPORT_AGENT on vendor mutation endpoints (method-level @Roles(ADMIN))', () => {
      // PATCH :id/sponsorship, PATCH :id/subscription, PATCH :vendorId/documents/:id -> method overrides to [ADMIN]
      const ctx = createMockContext(Role.SUPPORT_AGENT, [Role.ADMIN], [Role.ADMIN, Role.SUPPORT_AGENT]);
      expect(() => rolesGuard.canActivate(ctx)).toThrow('Access denied: Requires one of these roles: ADMIN');
    });

    it('7. should ALLOW ADMIN on vendor mutation endpoints (method-level @Roles(ADMIN))', () => {
      const ctx = createMockContext(Role.ADMIN, [Role.ADMIN], [Role.ADMIN, Role.SUPPORT_AGENT]);
      expect(rolesGuard.canActivate(ctx)).toBe(true);
    });

    it('8. should DENY CUSTOMER and VENDOR on all admin vendor endpoints', () => {
      const custCtx = createMockContext(Role.CUSTOMER, [Role.ADMIN], [Role.ADMIN, Role.SUPPORT_AGENT]);
      expect(() => rolesGuard.canActivate(custCtx)).toThrow();

      const vendCtx = createMockContext(Role.VENDOR, [Role.ADMIN], [Role.ADMIN, Role.SUPPORT_AGENT]);
      expect(() => rolesGuard.canActivate(vendCtx)).toThrow();
    });
  });
});
