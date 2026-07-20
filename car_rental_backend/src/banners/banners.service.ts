import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class BannersService {
  constructor(private readonly prisma: PrismaService) {}

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

  async create(data: { imageUrl: string; title: string; ctaLink?: string; displayOrder: number }) {
    return this.prisma.banner.create({
      data: {
        ...data,
        isActive: true,
      },
    });
  }

  async update(id: string, data: { imageUrl?: string; title?: string; ctaLink?: string; displayOrder?: number; isActive?: boolean }) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    return this.prisma.banner.update({
      where: { id },
      data,
    });
  }

  async delete(id: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    return this.prisma.banner.delete({
      where: { id },
    });
  }

  async toggleActive(id: string, isActive: boolean) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) {
      throw new NotFoundException(`Banner with ID ${id} not found`);
    }
    return this.prisma.banner.update({
      where: { id },
      data: { isActive },
    });
  }

  async reorder(orderedIds: string[]) {
    // Perform updates sequentially or in a transaction
    return this.prisma.$transaction(
      orderedIds.map((id, index) =>
        this.prisma.banner.update({
          where: { id },
          data: { displayOrder: index },
        }),
      ),
    );
  }
}
