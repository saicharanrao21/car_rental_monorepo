import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AdminPermission, StaffRole, getPermissionsForUser } from '../permissions.enum';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const { user, method } = req;

    // Read-only analyst guard: deny all mutating HTTP methods outright
    if (user && user.staffRole === StaffRole.READONLY_ANALYST) {
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
        throw new ForbiddenException(
          'Access denied: Read-only analysts are strictly prohibited from mutating marketplace records.',
        );
      }
    }

    const requiredPermissions = this.reflector.getAllAndOverride<AdminPermission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    if (!user || !user.role) {
      throw new ForbiddenException('Access denied: Unauthorized user context.');
    }

    const userRole = user.role as Role;
    const grantedPermissions = getPermissionsForUser(userRole, user.staffRole);

    const hasAll = requiredPermissions.every((perm) =>
      grantedPermissions.includes(perm),
    );

    if (!hasAll) {
      throw new ForbiddenException(
        `Access denied: Missing required permission(s): ${requiredPermissions.join(', ')}`,
      );
    }

    return true;
  }
}
