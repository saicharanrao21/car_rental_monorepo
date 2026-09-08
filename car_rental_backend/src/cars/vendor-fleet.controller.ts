import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, VehicleOperationalStatus } from '@prisma/client';
import { VendorFleetService } from './vendor-fleet.service';
import { VehicleOperationsEligibilityService } from './vehicle-operations-eligibility.service';
import { VehicleLifecycleService } from './vehicle-lifecycle.service';
import { CreateCarDto } from './dto/create-car.dto';
import { UpdateCarDto } from './dto/update-car.dto';
import {
  AssignServiceAreaDto,
  StartMaintenanceDto,
  CompleteMaintenanceDto,
} from './dto/vendor-fleet.dto';

@Controller('vendor/fleet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.VENDOR)
export class VendorFleetController {
  constructor(
    private readonly fleetService: VendorFleetService,
    private readonly eligibilityService: VehicleOperationsEligibilityService,
    private readonly lifecycleService: VehicleLifecycleService,
  ) {}

  @Get()
  async getMyFleet(@Req() req: any) {
    return this.fleetService.getVendorFleet(req.user.userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async createVehicle(@Req() req: any, @Body() dto: CreateCarDto) {
    return this.fleetService.createVehicle(req.user.userId, dto);
  }

  @Patch(':id')
  async updateVehicle(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateCarDto,
  ) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.fleetService.updateVehicle(
      id,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      dto,
    );
  }

  @Get(':id/readiness')
  async getVehicleReadiness(@Param('id') id: string, @Req() req: any) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    const result = await this.eligibilityService.evaluateEligibility(id, { skipCache: true });
    if (result.vendorId !== vendor.id) {
      throw new ForbiddenException('You do not have permission to view readiness for this vehicle.');
    }
    return result;
  }

  @Post(':id/submit-verification')
  @HttpCode(HttpStatus.OK)
  async submitForVerification(@Param('id') id: string, @Req() req: any) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.fleetService.submitForVerification(id, {
      id: req.user.userId,
      role: Role.VENDOR,
      vendorId: vendor.id,
    });
  }

  @Post(':id/activate')
  @HttpCode(HttpStatus.OK)
  async activateVehicle(@Param('id') id: string, @Req() req: any) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.lifecycleService.transitionStatus(
      id,
      VehicleOperationalStatus.ACTIVE,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      { reason: 'Vendor requested operational vehicle activation' },
    );
  }

  @Post(':id/deactivate')
  @HttpCode(HttpStatus.OK)
  async deactivateVehicle(@Param('id') id: string, @Req() req: any) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.lifecycleService.transitionStatus(
      id,
      VehicleOperationalStatus.INACTIVE,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      { reason: 'Vendor requested vehicle deactivation' },
    );
  }

  @Post(':id/service-area')
  @HttpCode(HttpStatus.OK)
  async assignServiceArea(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: AssignServiceAreaDto,
  ) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.fleetService.assignServiceArea(
      id,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      dto,
    );
  }

  @Post(':id/maintenance/start')
  @HttpCode(HttpStatus.OK)
  async startMaintenance(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: StartMaintenanceDto,
  ) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.fleetService.startMaintenance(
      id,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      dto,
    );
  }

  @Post(':id/maintenance/complete')
  @HttpCode(HttpStatus.OK)
  async completeMaintenance(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: CompleteMaintenanceDto,
  ) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    return this.fleetService.completeMaintenance(
      id,
      { id: req.user.userId, role: Role.VENDOR, vendorId: vendor.id },
      dto,
    );
  }

  @Get(':id/audit-logs')
  async getVehicleAuditLogs(@Param('id') id: string, @Req() req: any) {
    const vendor = await this.fleetService.getVendorByUserId(req.user.userId);
    const car = await this.fleetService.getVehicleAuditLogs(id);
    return car;
  }
}
