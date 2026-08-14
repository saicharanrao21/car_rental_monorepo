import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { SupportedCitiesService } from './supported-cities.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
export class SupportedCitiesController {
  constructor(
    private readonly supportedCitiesService: SupportedCitiesService,
  ) {}

  // 1. PUBLIC ENDPOINTS
  @Get('supported-cities')
  async getActiveCities() {
    return this.supportedCitiesService.findAllActive();
  }

  @Get('supported-cities/nearest')
  async getNearestCity(
    @Query('lat') latStr: string,
    @Query('lng') lngStr: string,
  ) {
    const lat = parseFloat(latStr);
    const lng = parseFloat(lngStr);
    return this.supportedCitiesService.findNearest(lat, lng);
  }

  // 2. ADMIN ENDPOINTS
  @Get('admin/supported-cities')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAllCitiesAdmin() {
    return this.supportedCitiesService.findAllAdmin();
  }

  @Post('admin/supported-cities')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async createCity(
    @Req() req: any,
    @Body()
    dto: {
      name: string;
      state: string;
      latitude: number;
      longitude: number;
      isActive?: boolean;
    },
  ) {
    return this.supportedCitiesService.create(dto, req.user.userId);
  }

  @Patch('admin/supported-cities/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updateCity(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    dto: {
      name?: string;
      state?: string;
      latitude?: number;
      longitude?: number;
      isActive?: boolean;
    },
  ) {
    return this.supportedCitiesService.update(id, dto, req.user.userId);
  }

  @Delete('admin/supported-cities/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async deleteCity(@Req() req: any, @Param('id') id: string) {
    return this.supportedCitiesService.delete(id, req.user.userId);
  }
}
