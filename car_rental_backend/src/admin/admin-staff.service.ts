import {
  Injectable,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from './audit-log.service';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import {
  StaffRole,
  STAFF_ROLE_PERMISSIONS_MATRIX,
} from '../auth/permissions.enum';

@Injectable()
export class AdminStaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async findAll(query: { search?: string; staffRole?: string; page?: number; limit?: number }) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: any = {
      role: { in: [Role.ADMIN, Role.SUPPORT_AGENT] },
    };

    if (query.staffRole) {
      where.staffRole = query.staffRole;
    }

    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { email: { contains: query.search, mode: 'insensitive' } },
        { phone: { contains: query.search } },
      ];
    }

    const [total, users] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          staffRole: true,
          banned: true,
          profilePhotoUrl: true,
          createdAt: true,
          updatedAt: true,
          _count: {
            select: { refreshTokens: { where: { revoked: false, expiresAt: { gt: new Date() } } } },
          },
        },
      }),
    ]);

    return {
      data: users.map((u) => ({
        ...u,
        activeSessions: u._count.refreshTokens,
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        id,
        role: { in: [Role.ADMIN, Role.SUPPORT_AGENT] },
      },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        staffRole: true,
        banned: true,
        profilePhotoUrl: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: { refreshTokens: { where: { revoked: false } } },
        },
      },
    });

    if (!user) {
      throw new NotFoundException(`Staff user #${id} not found.`);
    }

    return {
      ...user,
      activeSessions: user._count.refreshTokens,
    };
  }

  async createStaff(dto: CreateStaffDto, currentAdminId: string) {
    // 1. Verify phone uniqueness
    const existingPhone = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (existingPhone) {
      throw new ConflictException(`User with phone ${dto.phone} already exists.`);
    }

    // 2. Verify email uniqueness
    const existingEmail = await this.prisma.user.findFirst({
      where: { email: dto.email },
    });
    if (existingEmail) {
      throw new ConflictException(`User with email ${dto.email} already exists.`);
    }

    // 3. Hash initial password
    const passwordHash = bcrypt.hashSync(dto.password, 10);

    // 4. Map staff role to base Prisma Role
    const baseRole =
      dto.staffRole === StaffRole.CUSTOMER_SUPPORT
        ? Role.SUPPORT_AGENT
        : Role.ADMIN;

    const staffUser = await this.prisma.user.create({
      data: {
        name: dto.name,
        email: dto.email,
        phone: dto.phone,
        role: baseRole,
        staffRole: dto.staffRole,
        passwordHash,
      },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        staffRole: true,
        banned: true,
        createdAt: true,
      },
    });

    await this.auditLogService.log(
      currentAdminId,
      'STAFF_ACCOUNT_PROVISIONED',
      'User',
      staffUser.id,
      {
        name: staffUser.name,
        email: staffUser.email,
        staffRole: staffUser.staffRole,
        baseRole: staffUser.role,
      },
    );

    return staffUser;
  }

  async updateStaff(id: string, dto: UpdateStaffDto, currentAdminId: string) {
    const staff = await this.prisma.user.findUnique({
      where: { id },
    });

    if (!staff) {
      throw new NotFoundException(`Staff member #${id} not found.`);
    }

    // Safety assert: Super Admin cannot ban themselves
    if (id === currentAdminId && dto.banned === true) {
      throw new BadRequestException('Security Assertion: An administrator cannot suspend their own account.');
    }

    const data: any = {};
    if (dto.name) data.name = dto.name;
    if (dto.staffRole) {
      data.staffRole = dto.staffRole;
      data.role =
        dto.staffRole === StaffRole.CUSTOMER_SUPPORT
          ? Role.SUPPORT_AGENT
          : Role.ADMIN;
    }
    if (dto.banned !== undefined) data.banned = dto.banned;
    if (dto.password && dto.password.trim().length >= 8) {
      data.passwordHash = bcrypt.hashSync(dto.password.trim(), 10);
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        staffRole: true,
        banned: true,
        updatedAt: true,
      },
    });

    await this.auditLogService.log(
      currentAdminId,
      'STAFF_ACCOUNT_UPDATED',
      'User',
      id,
      {
        updatedFields: Object.keys(data),
        staffRole: updated.staffRole,
        banned: updated.banned,
      },
    );

    return updated;
  }

  async revokeSessions(id: string, currentAdminId: string) {
    const staff = await this.prisma.user.findUnique({ where: { id } });
    if (!staff) {
      throw new NotFoundException(`Staff user #${id} not found.`);
    }

    const result = await this.prisma.refreshToken.updateMany({
      where: { userId: id, revoked: false },
      data: { revoked: true },
    });

    await this.auditLogService.log(
      currentAdminId,
      'STAFF_SESSIONS_REVOKED',
      'User',
      id,
      {
        revokedSessionCount: result.count,
      },
    );

    return {
      success: true,
      revokedCount: result.count,
      message: `Revoked ${result.count} active session(s) for ${staff.name}.`,
    };
  }

  getRoleDefinitions() {
    return [
      {
        role: StaffRole.SUPER_ADMIN,
        title: 'Super Admin',
        description: 'Complete unrestricted access across global marketplace settings, integrations, permissions, and financial controls.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.SUPER_ADMIN],
      },
      {
        role: StaffRole.OPERATIONS_MANAGER,
        title: 'Operations Manager',
        description: 'Operational control over vendor onboarding, vehicle approvals, active bookings, pickup hubs, and service areas.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.OPERATIONS_MANAGER],
      },
      {
        role: StaffRole.FINANCE_MANAGER,
        title: 'Finance Manager',
        description: 'Authority to inspect financial ledgers, approve and execute vendor payouts, adjudicate refunds, and configure commissions.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.FINANCE_MANAGER],
      },
      {
        role: StaffRole.CUSTOMER_SUPPORT,
        title: 'Customer Support',
        description: 'Assigned to triage customer inquiries, update support tickets, coordinate emergency dispatch, and handle customer complaints.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.CUSTOMER_SUPPORT],
      },
      {
        role: StaffRole.COMPLIANCE_OFFICER,
        title: 'Compliance Officer',
        description: 'Reviews KYC identity documents, inspects vendor registration requirements, manages disputes, and processes privacy requests.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.COMPLIANCE_OFFICER],
      },
      {
        role: StaffRole.MARKETING_MANAGER,
        title: 'Marketing Manager',
        description: 'Manages promotional banners, coupon campaigns, referral incentives, loyalty program rules, and broadcast notifications.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.MARKETING_MANAGER],
      },
      {
        role: StaffRole.READONLY_ANALYST,
        title: 'Read-only Analyst',
        description: 'Audit-level view-only access across business dashboards, analytics reports, and logs with zero mutation privileges.',
        permissions: STAFF_ROLE_PERMISSIONS_MATRIX[StaffRole.READONLY_ANALYST],
      },
    ];
  }
}
