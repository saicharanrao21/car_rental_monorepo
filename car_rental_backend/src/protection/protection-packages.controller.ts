import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ProtectionPackagesService } from './protection-packages.service';
import { CreateProtectionPackageDto } from './dto/create-protection-package.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
export class ProtectionPackagesController {
  constructor(private readonly protectionService: ProtectionPackagesService) {}

  /**
   * Public endpoint to fetch active protection packages available in a city.
   */
  @Get('protection-packages')
  async getActivePackages(@Query('city') city?: string) {
    return this.protectionService.getActivePackages(city);
  }

  /**
   * Admin creates a new protection package.
   */
  @Post('admin/protection-packages')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async createPackage(@Body() dto: CreateProtectionPackageDto) {
    return this.protectionService.createPackage(dto);
  }

  /**
   * Admin updates a protection package.
   */
  @Patch('admin/protection-packages/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async updatePackage(
    @Param('id') id: string,
    @Body() dto: Partial<CreateProtectionPackageDto>,
  ) {
    return this.protectionService.updatePackage(id, dto);
  }
}
