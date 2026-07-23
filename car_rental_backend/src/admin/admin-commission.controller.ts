import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, CarCategory, TripType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin/commission-rules')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminCommissionController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async getRules() {
    const rules = await this.prisma.commissionConfig.findMany({
      orderBy: { createdAt: 'desc' },
    });
    return rules.map(rule => ({
      id: rule.id,
      city: rule.city ?? 'All Cities',
      carCategory: rule.carCategory ?? 'All Categories',
      tripType: rule.tripType ?? 'All Trip Types',
      percentage: Number(rule.percentage),
      effectiveFrom: rule.effectiveFrom.toISOString(),
    }));
  }

  @Post()
  async createRule(
    @Body() dto: {
      tripType?: string;
      city?: string;
      carCategory?: string;
      percentage: number;
      effectiveFrom?: string;
    },
  ) {
    const city = !dto.city || dto.city === 'All' || dto.city === 'All Cities' ? null : dto.city;
    const carCategory = !dto.carCategory || dto.carCategory === 'All' || dto.carCategory === 'All Categories'
      ? null
      : (dto.carCategory as CarCategory);
    const tripType = !dto.tripType || dto.tripType === 'All' || dto.tripType === 'All Trip Types'
      ? null
      : (dto.tripType as TripType);

    const rule = await this.prisma.commissionConfig.create({
      data: {
        city,
        carCategory,
        tripType,
        percentage: new Prisma.Decimal(dto.percentage),
        effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : new Date(),
      },
    });

    return {
      id: rule.id,
      city: rule.city ?? 'All Cities',
      carCategory: rule.carCategory ?? 'All Categories',
      tripType: rule.tripType ?? 'All Trip Types',
      percentage: Number(rule.percentage),
      effectiveFrom: rule.effectiveFrom.toISOString(),
    };
  }

  @Patch(':id')
  async updateRule(
    @Param('id') id: string,
    @Body() dto: {
      tripType?: string;
      city?: string;
      carCategory?: string;
      percentage?: number;
      effectiveFrom?: string;
    },
  ) {
    const data: any = {};
    if (dto.percentage !== undefined) data.percentage = new Prisma.Decimal(dto.percentage);
    if (dto.city !== undefined) data.city = (!dto.city || dto.city === 'All' || dto.city === 'All Cities') ? null : dto.city;
    if (dto.carCategory !== undefined) data.carCategory = (!dto.carCategory || dto.carCategory === 'All' || dto.carCategory === 'All Categories') ? null : (dto.carCategory as CarCategory);
    if (dto.tripType !== undefined) data.tripType = (!dto.tripType || dto.tripType === 'All' || dto.tripType === 'All Trip Types') ? null : (dto.tripType as TripType);
    if (dto.effectiveFrom !== undefined) data.effectiveFrom = new Date(dto.effectiveFrom);

    const rule = await this.prisma.commissionConfig.update({
      where: { id },
      data,
    });

    return {
      id: rule.id,
      city: rule.city ?? 'All Cities',
      carCategory: rule.carCategory ?? 'All Categories',
      tripType: rule.tripType ?? 'All Trip Types',
      percentage: Number(rule.percentage),
      effectiveFrom: rule.effectiveFrom.toISOString(),
    };
  }

  @Delete(':id')
  async deleteRule(@Param('id') id: string) {
    await this.prisma.commissionConfig.delete({
      where: { id },
    });
    return { success: true };
  }
}
