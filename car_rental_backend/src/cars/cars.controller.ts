import {
  Controller,
  Get,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { CarsService } from './cars.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, TripType } from '@prisma/client';
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
  async findOne(@Req() req: any, @Param('id') id: string) {
    const authUser = await this.getAuthUser(req);
    return this.carsService.findOne(id, authUser);
  }

  @Get('cars/:id/availability-calendar')
  async getAvailabilityCalendar(
    @Param('id') id: string,
    @Query('month') month?: string,
  ) {
    return this.carsService.getAvailabilityCalendar(id, month);
  }

  @Get('cars/:id/mileage-packages')
  async getCarMileagePackages(
    @Param('id') id: string,
    @Query('tripType') tripType?: TripType,
  ) {
    return this.carsService.getCarMileagePackages(id, tripType, true);
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

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch('admin/cars/:carId/mileage-packages/:packageId/toggle-active')
  async adminToggleMileagePackageActive(
    @Param('carId') carId: string,
    @Param('packageId') packageId: string,
    @Body('isActive') isActive?: boolean,
  ) {
    return this.carsService.adminToggleMileagePackageActive(carId, packageId, isActive);
  }

  // --- Helper Methods ---

  private async getAuthUser(
    req: any,
  ): Promise<{ userId: string; role: Role } | undefined> {
    const authHeader = req.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return undefined;
    }
    const token = authHeader.split(' ')[1];
    const secret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dev_access_secret_key_change_me_12345!';
    try {
      const verified: any = await this.jwtService.verifyAsync(token, {
        secret,
      });
      if (verified && verified.userId && verified.role) {
        return { userId: verified.userId, role: verified.role };
      }
      return undefined;
    } catch {
      return undefined;
    }
  }

  private async getIsAdmin(req: any): Promise<boolean> {
    const user = await this.getAuthUser(req);
    return user?.role === Role.ADMIN || user?.role === Role.SUPPORT_AGENT;
  }
}
