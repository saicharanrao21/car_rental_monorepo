import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogQueryDto } from './dto/audit-log-query.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class AuditLogService {
  private readonly logger = new Logger(AuditLogService.name);

  constructor(private readonly prisma: PrismaService) {}

  private sanitizeMetadata(data: any): any {
    if (!data || typeof data !== 'object') {
      return data;
    }

    if (Array.isArray(data)) {
      return data.map((item) => this.sanitizeMetadata(item));
    }

    const SENSITIVE_KEYS = new Set([
      'password',
      'passwordhash',
      'token',
      'refreshtoken',
      'accesstoken',
      'secret',
      'apikey',
      'authorization',
      'creditcard',
      'cardnumber',
      'cvv',
      'cvc',
      'pin',
      'otp',
    ]);

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(data)) {
      const lowerKey = key.toLowerCase().replace(/[-_]/g, '');
      if (SENSITIVE_KEYS.has(lowerKey)) {
        sanitized[key] = '[REDACTED]';
      } else if (value && typeof value === 'object') {
        sanitized[key] = this.sanitizeMetadata(value);
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  async log(
    adminUserId: string,
    action: string,
    targetType: string,
    targetId: string,
    metadata?: any,
  ): Promise<void> {
    try {
      const sanitizedMeta = metadata ? this.sanitizeMetadata(metadata) : Prisma.JsonNull;
      await this.prisma.auditLog.create({
        data: {
          adminUserId,
          action,
          targetType,
          targetId,
          metadata: sanitizedMeta,
        },
      });
    } catch (err) {
      this.logger.error(
        `Failed to record audit log for action ${action}:`,
        err,
      );
    }
  }

  async getAuditLogs(query: AuditLogQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.AuditLogWhereInput = {};

    if (query.adminUserId) {
      where.adminUserId = query.adminUserId;
    }

    if (query.action) {
      where.action = { equals: query.action, mode: 'insensitive' };
    }

    if (query.targetType) {
      where.targetType = { equals: query.targetType, mode: 'insensitive' };
    }

    if (query.startDate || query.endDate) {
      where.createdAt = {};
      if (query.startDate) {
        where.createdAt.gte = new Date(query.startDate);
      }
      if (query.endDate) {
        where.createdAt.lte = new Date(query.endDate);
      }
    }

    const [total, data] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          adminUser: {
            select: {
              id: true,
              name: true,
              email: true,
              role: true,
            },
          },
        },
      }),
    ]);

    return {
      data,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }
}
