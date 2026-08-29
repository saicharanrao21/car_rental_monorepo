import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AdminPermission, ROLE_PERMISSIONS_MATRIX } from '../permissions.enum';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<AdminPermission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();

    if (!user || !user.role) {
      throw new ForbiddenException('Access denied: Unauthorized user context.');
    }

    const userRole = user.role as Role;
    const grantedPermissions = ROLE_PERMISSIONS_MATRIX[userRole] || [];

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
