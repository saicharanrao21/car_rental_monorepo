import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ServiceAreasService } from './service-areas.service';
import {
  CreateCityDto,
  UpdateCityDto,
  SetCityStatusDto,
  CreateServiceAreaDto,
  UpdateServiceAreaDto,
  SetServiceAreaStatusDto,
  AssignVendorServiceAreaDto,
  ServiceAreaQueryDto,
  ServiceabilityQueryDto,
  ServiceAreaStatus,
} from './dto/service-area.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';

@Controller()
export class ServiceAreasController {
  constructor(private readonly serviceAreasService: ServiceAreasService) {}

  // =========================================================================
  // PUBLIC & CUSTOMER / VENDOR ENDPOINTS
  // =========================================================================

  /**
   * Public: Query active service areas (localities) in an operational city
   */
  @Get('locations/service-areas')
  async getPublicServiceAreas(@Query() query: ServiceAreaQueryDto) {
    return this.serviceAreasService.findAllServiceAreas({
      ...query,
      status: ServiceAreaStatus.ACTIVE,
    });
  }

  /**
   * Public: Retrieve details of a specific service area
   */
  @Get('locations/service-areas/:id')
  async getPublicServiceAreaById(@Param('id') id: string) {
    return this.serviceAreasService.findServiceAreaById(id);
  }

  /**
   * Public / Customer: Server-Authoritative Serviceability & Location Resolution
   * Evaluates GPS coordinates, matches against active/coming soon service areas,
   * and calculates nearest serviceable areas.
   */
  @Get('locations/serviceability')
  async resolveServiceability(@Query() query: ServiceabilityQueryDto) {
    return this.serviceAreasService.resolveServiceability(query);
  }

  // =========================================================================
  // ADMIN: CITY MANAGEMENT
  // =========================================================================

  @Get('admin/locations/cities')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_READ)
  async adminGetAllCities(@Query('includeInactive') includeInactive?: string) {
    const showInactive = includeInactive === 'true' || includeInactive === '1';
    return this.serviceAreasService.findAllCities(showInactive);
  }

  @Get('admin/locations/cities/:id')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_READ)
  async adminGetCityById(@Param('id') id: string) {
    return this.serviceAreasService.findCityById(id);
  }

  @Post('admin/locations/cities')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminCreateCity(@Req() req: any, @Body() dto: CreateCityDto) {
    return this.serviceAreasService.createCity(dto, req.user?.userId || 'system-admin');
  }

  @Put('admin/locations/cities/:id')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminUpdateCity(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateCityDto,
  ) {
    return this.serviceAreasService.updateCity(id, dto, req.user?.userId || 'system-admin');
  }

  @Patch('admin/locations/cities/:id/status')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminSetCityStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: SetCityStatusDto,
  ) {
    return this.serviceAreasService.setCityStatus(
      id,
      dto.status,
      req.user?.userId || 'system-admin',
      dto.reason,
    );
  }

  // =========================================================================
  // ADMIN: SERVICE AREA MANAGEMENT
  // =========================================================================

  @Get('admin/locations/service-areas')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_READ)
  async adminGetAllServiceAreas(@Query() query: ServiceAreaQueryDto) {
    return this.serviceAreasService.findAllServiceAreas(query);
  }

  @Get('admin/locations/service-areas/:id')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_READ)
  async adminGetServiceAreaById(@Param('id') id: string) {
    return this.serviceAreasService.findServiceAreaById(id);
  }

  @Post('admin/locations/service-areas')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminCreateServiceArea(
    @Req() req: any,
    @Body() dto: CreateServiceAreaDto,
  ) {
    return this.serviceAreasService.createServiceArea(
      dto,
      req.user?.userId || 'system-admin',
    );
  }

  @Put('admin/locations/service-areas/:id')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminUpdateServiceArea(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateServiceAreaDto,
  ) {
    return this.serviceAreasService.updateServiceArea(
      id,
      dto,
      req.user?.userId || 'system-admin',
    );
  }

  @Patch('admin/locations/service-areas/:id/status')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminSetServiceAreaStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: SetServiceAreaStatusDto,
  ) {
    return this.serviceAreasService.setServiceAreaStatus(
      id,
      dto.status,
      req.user?.userId || 'system-admin',
      dto.reason,
    );
  }

  // =========================================================================
  // ADMIN: VENDOR COVERAGE ASSIGNMENTS
  // =========================================================================

  @Get('admin/locations/vendors/:vendorId/areas')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_READ)
  async adminGetVendorServiceAreas(@Param('vendorId') vendorId: string) {
    return this.serviceAreasService.getVendorServiceAreas(vendorId);
  }

  @Post('admin/locations/vendors/:vendorId/areas')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminAssignVendorArea(
    @Req() req: any,
    @Param('vendorId') vendorId: string,
    @Body() dto: AssignVendorServiceAreaDto,
  ) {
    return this.serviceAreasService.assignVendorToServiceArea(
      { ...dto, vendorId },
      req.user?.userId || 'system-admin',
    );
  }

  @Delete('admin/locations/vendors/:vendorId/areas/:serviceAreaId')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminRemoveVendorArea(
    @Req() req: any,
    @Param('vendorId') vendorId: string,
    @Param('serviceAreaId') serviceAreaId: string,
    @Query('reason') reason?: string,
  ) {
    return this.serviceAreasService.removeVendorFromServiceArea(
      vendorId,
      serviceAreaId,
      req.user?.userId || 'system-admin',
      reason,
    );
  }

  @Patch('admin/locations/vendors/:vendorId/areas/:serviceAreaId/primary')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.LOCATION_WRITE)
  async adminSetVendorPrimaryArea(
    @Req() req: any,
    @Param('vendorId') vendorId: string,
    @Param('serviceAreaId') serviceAreaId: string,
  ) {
    return this.serviceAreasService.setVendorPrimaryArea(
      vendorId,
      serviceAreaId,
      req.user?.userId || 'system-admin',
    );
  }
}
