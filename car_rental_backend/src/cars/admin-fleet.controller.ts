import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role, VehicleOperationalStatus } from '@prisma/client';
import { VendorFleetService } from './vendor-fleet.service';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';
import { VehicleLifecycleService } from './vehicle-lifecycle.service';
import {
  AdminFleetQueryDto,
  AdminVerifyVehicleDto,
  AdminRejectVehicleDto,
  AdminSuspendVehicleDto,
  AdminRetireVehicleDto,
  StartMaintenanceDto,
  CompleteMaintenanceDto,
} from './dto/vendor-fleet.dto';

@Controller('admin/fleet')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
@Roles(Role.ADMIN, Role.SUPPORT_AGENT)
export class AdminFleetController {
  constructor(
    private readonly fleetService: VendorFleetService,
    private readonly eligibilityService: VehicleOperationsEligibilityService,
    private readonly lifecycleService: VehicleLifecycleService,
  ) {}

  @Get('kpis')
  @RequirePermissions(AdminPermission.FLEET_READ)
  async getFleetKPIs() {
    return this.fleetService.getFleetKPIs();
  }

  @Get()
  @RequirePermissions(AdminPermission.FLEET_READ)
  async getFleet(@Query() query: AdminFleetQueryDto) {
    return this.fleetService.getAdminFleet(query);
  }

  @Get(':id/readiness')
  @RequirePermissions(AdminPermission.FLEET_READ)
  async getVehicleReadiness(@Param('id') id: string) {
    return this.eligibilityService.evaluateEligibility(id, { skipCache: true });
  }

  @Get(':id/audit-logs')
  @RequirePermissions(AdminPermission.FLEET_READ)
  async getVehicleAuditLogs(@Param('id') id: string) {
    return this.fleetService.getVehicleAuditLogs(id);
  }

  @Post(':id/verify')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_VERIFY)
  async verifyVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: AdminVerifyVehicleDto,
  ) {
    return this.fleetService.adminVerifyVehicle(id, req.user.userId, dto);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_VERIFY)
  async rejectVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: AdminRejectVehicleDto,
  ) {
    return this.fleetService.adminRejectVehicle(id, req.user.userId, dto);
  }

  @Post(':id/activate')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async activateVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body: { reason?: string },
  ) {
    return this.lifecycleService.transitionStatus(
      id,
      VehicleOperationalStatus.ACTIVE,
      { id: req.user.userId, role: req.user.role },
      { reason: body?.reason || 'Activated by platform administrator' },
    );
  }

  @Post(':id/deactivate')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async deactivateVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body: { reason?: string },
  ) {
    return this.lifecycleService.transitionStatus(
      id,
      VehicleOperationalStatus.INACTIVE,
      { id: req.user.userId, role: req.user.role },
      { reason: body?.reason || 'Deactivated by platform administrator' },
    );
  }

  @Post(':id/suspend')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async suspendVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: AdminSuspendVehicleDto,
  ) {
    return this.fleetService.adminSuspendVehicle(id, req.user.userId, dto);
  }

  @Post(':id/retire')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async retireVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: AdminRetireVehicleDto,
  ) {
    return this.fleetService.adminRetireVehicle(id, req.user.userId, dto);
  }

  @Post(':id/maintenance/start')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async startMaintenance(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: StartMaintenanceDto,
  ) {
    return this.fleetService.startMaintenance(
      id,
      { id: req.user.userId, role: req.user.role },
      dto,
    );
  }

  @Post(':id/maintenance/complete')
  @HttpCode(HttpStatus.OK)
  @RequirePermissions(AdminPermission.FLEET_WRITE)
  async completeMaintenance(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: CompleteMaintenanceDto,
  ) {
    return this.fleetService.completeMaintenance(
      id,
      { id: req.user.userId, role: req.user.role },
      dto,
    );
  }
}
