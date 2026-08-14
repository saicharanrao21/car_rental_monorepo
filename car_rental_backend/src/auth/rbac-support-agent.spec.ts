import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ForbiddenException } from '@nestjs/common';
import { RolesGuard } from './guards/roles.guard';
import { ROLES_KEY } from './decorators/roles.decorator';

describe('RBAC & SUPPORT_AGENT Role Authorization (Phase 1)', () => {
  let rolesGuard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    rolesGuard = new RolesGuard(reflector);
  });

  function createMockExecutionContext(userRole: Role, allowedRoles?: Role[]) {
    const req: any = {
      user: {
        userId: 'test-user-id',
        role: userRole,
      },
    };

    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(allowedRoles);

    return {
      switchToHttp: () => ({
        getRequest: () => req,
        getResponse: () => ({}),
      }),
      getHandler: () => ({}),
      getClass: () => ({}),
    };
  }

  it('should allow ADMIN on admin-only routes', () => {
    const ctx = createMockExecutionContext(Role.ADMIN, [Role.ADMIN]);
    expect(rolesGuard.canActivate(ctx as any)).toBe(true);
  });

  it('should allow SUPPORT_AGENT on support-accessible routes', () => {
    const ctx = createMockExecutionContext(Role.SUPPORT_AGENT, [
      Role.ADMIN,
      Role.SUPPORT_AGENT,
    ]);
    expect(rolesGuard.canActivate(ctx as any)).toBe(true);
  });

  it('should deny SUPPORT_AGENT on admin-only financial/destructive routes', () => {
    const ctx = createMockExecutionContext(Role.SUPPORT_AGENT, [Role.ADMIN]);
    expect(() => rolesGuard.canActivate(ctx as any)).toThrow(
      ForbiddenException,
    );
  });

  it('should deny CUSTOMER on support-accessible routes', () => {
    const ctx = createMockExecutionContext(Role.CUSTOMER, [
      Role.ADMIN,
      Role.SUPPORT_AGENT,
    ]);
    expect(() => rolesGuard.canActivate(ctx as any)).toThrow(
      ForbiddenException,
    );
  });

  it('should deny VENDOR on support-accessible routes', () => {
    const ctx = createMockExecutionContext(Role.VENDOR, [
      Role.ADMIN,
      Role.SUPPORT_AGENT,
    ]);
    expect(() => rolesGuard.canActivate(ctx as any)).toThrow(
      ForbiddenException,
    );
  });

  it('should allow all authenticated roles if route does not specify @Roles', () => {
    const ctx = createMockExecutionContext(Role.CUSTOMER, undefined);
    expect(rolesGuard.canActivate(ctx as any)).toBe(true);
  });
});
