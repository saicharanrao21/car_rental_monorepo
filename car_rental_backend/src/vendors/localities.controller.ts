import { Controller, Get, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('localities')
export class LocalitiesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getLocalities(
    @Query('city') city?: string,
    @Query('search') search?: string,
  ) {
    const where: any = {
      locality: { not: null },
    };

    if (city) {
      where.city = { equals: city, mode: 'insensitive' };
    }

    if (search) {
      where.locality = { startsWith: search, mode: 'insensitive' };
    }

    const vendors = await this.prisma.vendor.findMany({
      where,
      select: { locality: true },
      distinct: ['locality'],
      take: 10,
    });

    return vendors
      .map((v) => v.locality)
      .filter((loc): loc is string => Boolean(loc));
  }
}
