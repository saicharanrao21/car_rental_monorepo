import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Req } from '@nestjs/common';
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
    @Req() req: any,
    @Body() dto: { imageUrl: string; title: string; ctaLink?: string; displayOrder: number },
  ) {
    return this.bannersService.create(dto, req.user.userId);
  }

  @Patch('admin/banners/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updateBanner(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: { imageUrl?: string; title?: string; ctaLink?: string; displayOrder?: number; isActive?: boolean },
  ) {
    return this.bannersService.update(id, dto, req.user.userId);
  }

  @Delete('admin/banners/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async deleteBanner(@Req() req: any, @Param('id') id: string) {
    return this.bannersService.delete(id, req.user.userId);
  }

  @Patch('admin/banners/:id/active')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async toggleActive(@Req() req: any, @Param('id') id: string, @Body('isActive') isActive: boolean) {
    return this.bannersService.toggleActive(id, isActive, req.user.userId);
  }

  @Post('admin/banners/reorder')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async reorderBanners(@Req() req: any, @Body('orderedIds') orderedIds: string[]) {
    return this.bannersService.reorder(orderedIds, req.user.userId);
  }
}
