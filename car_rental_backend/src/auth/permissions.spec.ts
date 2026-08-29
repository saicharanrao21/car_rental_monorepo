import { PermissionsGuard } from './guards/permissions.guard';
import { AdminPermission, ROLE_PERMISSIONS_MATRIX } from './permissions.enum';
import { Role } from '@prisma/client';
import { Reflector } from '@nestjs/core';
import { ForbiddenException, ExecutionContext } from '@nestjs/common';

describe('Phase 27.1 — Multi-Admin RBAC & Permissions Guard Tests', () => {
  let guard: PermissionsGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new PermissionsGuard(reflector);
  });

  function createMockContext(user: any): ExecutionContext {
    return {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => ({ user }),
      }),
    } as unknown as ExecutionContext;
  }

  it('allows full access to ADMIN (Super Admin) for any permission', () => {
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue([AdminPermission.SYSTEM_CONFIG_WRITE, AdminPermission.FINANCE_WRITE]);

    const context = createMockContext({ id: 'admin_1', role: Role.ADMIN });
    const canActivate = guard.canActivate(context);

    expect(canActivate).toBe(true);
  });

  it('allows SUPPORT_AGENT access to assigned support permissions', () => {
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue([AdminPermission.SUPPORT_TICKET_READ, AdminPermission.BOOKING_READ]);

    const context = createMockContext({ id: 'agent_1', role: Role.SUPPORT_AGENT });
    const canActivate = guard.canActivate(context);

    expect(canActivate).toBe(true);
  });

  it('denies SUPPORT_AGENT access to sensitive financial / system config permissions', () => {
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue([AdminPermission.SYSTEM_CONFIG_WRITE]);

    const context = createMockContext({ id: 'agent_1', role: Role.SUPPORT_AGENT });

    expect(() => guard.canActivate(context)).toThrow(ForbiddenException);
  });

  it('denies non-admin roles (CUSTOMER, VENDOR) from executing admin actions', () => {
    jest
      .spyOn(reflector, 'getAllAndOverride')
      .mockReturnValue([AdminPermission.USER_READ]);

    const contextCustomer = createMockContext({ id: 'cust_1', role: Role.CUSTOMER });
    expect(() => guard.canActivate(contextCustomer)).toThrow(ForbiddenException);

    const contextVendor = createMockContext({ id: 'vend_1', role: Role.VENDOR });
    expect(() => guard.canActivate(contextVendor)).toThrow(ForbiddenException);
  });

  it('allows public access if no permissions are specified on route', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);

    const context = createMockContext(null);
    expect(guard.canActivate(context)).toBe(true);
  });
});
