import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  Req,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Role } from '@prisma/client';
import { AdminPermission } from '../auth/permissions.enum';
import { AdminStaffService } from './admin-staff.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';

@Controller('admin/staff')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
export class AdminStaffController {
  constructor(private readonly staffService: AdminStaffService) {}

  @Get('roles')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  getRoleDefinitions() {
    return this.staffService.getRoleDefinitions();
  }

  @Get()
  @Roles(Role.ADMIN)
  async findAll(
    @Query('search') search?: string,
    @Query('staffRole') staffRole?: string,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.staffService.findAll({ search, staffRole, page, limit });
  }

  @Get(':id')
  @Roles(Role.ADMIN)
  async findOne(@Param('id') id: string) {
    return this.staffService.findOne(id);
  }

  @Post()
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async createStaff(@Req() req: any, @Body() dto: CreateStaffDto) {
    const adminUserId = req.user.userId || req.user.id;
    return this.staffService.createStaff(dto, adminUserId);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async updateStaff(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
  ) {
    const adminUserId = req.user.userId || req.user.id;
    return this.staffService.updateStaff(id, dto, adminUserId);
  }

  @Post(':id/revoke-sessions')
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async revokeSessions(@Req() req: any, @Param('id') id: string) {
    const adminUserId = req.user.userId || req.user.id;
    return this.staffService.revokeSessions(id, adminUserId);
  }
}

