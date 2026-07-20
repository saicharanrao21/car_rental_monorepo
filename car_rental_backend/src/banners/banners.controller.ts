import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { BannersService } from './banners.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  // 1. PUBLIC ENDPOINT (no guards)
  @Get('banners')
  async getActiveBanners() {
    return this.bannersService.getActiveBanners();
  }

  // 2. ADMIN ENDPOINTS
  @Get('admin/banners')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAllBanners() {
    return this.bannersService.findAll();
  }

  @Post('admin/banners')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async createBanner(
    @Body() dto: { imageUrl: string; title: string; ctaLink?: string; displayOrder: number },
  ) {
    return this.bannersService.create(dto);
  }

  @Patch('admin/banners/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updateBanner(
    @Param('id') id: string,
    @Body() dto: { imageUrl?: string; title?: string; ctaLink?: string; displayOrder?: number; isActive?: boolean },
  ) {
    return this.bannersService.update(id, dto);
  }

  @Delete('admin/banners/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async deleteBanner(@Param('id') id: string) {
    return this.bannersService.delete(id);
  }

  @Patch('admin/banners/:id/active')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async toggleActive(@Param('id') id: string, @Body('isActive') isActive: boolean) {
    return this.bannersService.toggleActive(id, isActive);
  }

  @Post('admin/banners/reorder')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async reorderBanners(@Body('orderedIds') orderedIds: string[]) {
    return this.bannersService.reorder(orderedIds);
  }
}
