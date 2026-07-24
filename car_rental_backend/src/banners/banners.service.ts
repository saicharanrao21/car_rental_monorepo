import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditLogService } from '../admin/audit-log.service';

@Injectable()
export class BannersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async getActiveBanners() {
    return this.prisma.banner.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: 'asc' },
    });
  }

  async findAll() {
    return this.prisma.banner.findMany({
      orderBy: { displayOrder: 'asc' },
    });
  }

  async create(data: { imageUrl: string; title: string; ctaLink?: string; displayOrder: number }, adminUserId?: string) {
    const banner = await this.prisma.banner.create({
      data: {
        ...data,
        isActive: true,
      },
    });
    if (adminUserId) {
      this.auditLogService.log(adminUserId, 'BANNER_CREATED', 'Banner', banner.id, data);
    }
    return banner;
  }

  async update(id: string, data: { imageUrl?: string; title?: string; ctaLink?: string; displayOrder?: number; isActive?: boolean }, adminUserId?: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    const updated = await this.prisma.banner.update({
      where: { id },
      data,
    });
    if (adminUserId) {
      this.auditLogService.log(adminUserId, 'BANNER_UPDATED', 'Banner', id, data);
    }
    return updated;
  }

  async delete(id: string, adminUserId?: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    const deleted = await this.prisma.banner.delete({
      where: { id },
    });
    if (adminUserId) {
      this.auditLogService.log(adminUserId, 'BANNER_DELETED', 'Banner', id);
    }
    return deleted;
  }

  async toggleActive(id: string, isActive: boolean, adminUserId?: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    const updated = await this.prisma.banner.update({
      where: { id },
      data: { isActive },
    });
    if (adminUserId) {
      this.auditLogService.log(adminUserId, 'BANNER_TOGGLE_ACTIVE', 'Banner', id, { isActive });
    }
    return updated;
  }

  async reorder(orderedIds: string[], adminUserId?: string) {
    const result = await this.prisma.$transaction(
      orderedIds.map((id, index) =>
        this.prisma.banner.update({
          where: { id },
          data: { displayOrder: index },
        }),
      ),
    );
    if (adminUserId) {
      this.auditLogService.log(adminUserId, 'BANNERS_REORDERED', 'Banner', 'all', { orderedIds });
    }
    return result;
  }
}
