import { Controller, Get, Patch, Param, Query, UseGuards, Req } from '@nestjs/common';
import { CarsService } from './cars.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CarsQueryDto } from './dto/cars-query.dto';
import { AdminCarsQueryDto } from './dto/admin-cars-query.dto';
import { JwtService } from '@nestjs/jwt';

@Controller()
export class CarsController {
  constructor(
    private readonly carsService: CarsService,
    private readonly jwtService: JwtService,
  ) {}

  @Get('cars')
  async searchCars(@Req() req: any, @Query() query: CarsQueryDto) {
    const isAdmin = this.getIsAdmin(req);
    return this.carsService.searchCars(query, isAdmin);
  }

  @Get('cars/:id')
  async findOne(@Param('id') id: string) {
    return this.carsService.findOne(id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
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

  private getIsAdmin(req: any): boolean {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return false;
    }
    const token = authHeader.split(' ')[1];
    try {
      const decoded: any = this.jwtService.decode(token);
      return decoded && decoded.role === Role.ADMIN;
    } catch {
      return false;
    }
  }
}
