import {
  Controller,
  Get,
  Patch,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { CarsService } from './cars.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CarsQueryDto } from './dto/cars-query.dto';
import { AdminCarsQueryDto } from './dto/admin-cars-query.dto';
import { JwtService } from '@nestjs/jwt';

import { ConfigService } from '@nestjs/config';

@Controller()
export class CarsController {
  constructor(
    private readonly carsService: CarsService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  @Get('cars')
  async searchCars(@Req() req: any, @Query() query: CarsQueryDto) {
    const isAdmin = await this.getIsAdmin(req);
    return this.carsService.searchCars(query, isAdmin);
  }

  @Get('cars/:id')
  async findOne(@Param('id') id: string) {
    return this.carsService.findOne(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  @Get('admin/cars')
  async adminFindAll(@Query() query: AdminCarsQueryDto) {
    return this.carsService.adminFindAll(query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('admin/cars/:id/deactivate')
  async adminDeactivate(@Param('id') id: string) {
    return this.carsService.adminDeactivate(id);
  }

  // --- Helper Methods ---

  private async getIsAdmin(req: any): Promise<boolean> {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return false;
    }
    const token = authHeader.split(' ')[1];
    const secret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dev_access_secret_key_change_me_12345!';
    try {
      const verified: any = await this.jwtService.verifyAsync(token, {
        secret,
      });
      return (
        verified &&
        (verified.role === Role.ADMIN || verified.role === Role.SUPPORT_AGENT)
      );
    } catch {
      return false;
    }
  }
}
