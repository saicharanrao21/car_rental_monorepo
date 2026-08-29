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
  BadRequestException,
} from '@nestjs/common';
import { LocationsService } from './locations.service';
import {
  ForwardGeocodeQueryDto,
  ReverseGeocodeQueryDto,
} from './dto/geocode-query.dto';
import { DistanceQueryDto } from './dto/distance-query.dto';
import {
  CreatePickupHubDto,
  UpdatePickupHubDto,
  PickupHubQueryDto,
} from './dto/pickup-hub.dto';
import {
  CreateSupportedCityDto,
  UpdateSupportedCityDto,
} from './dto/city-admin.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { AdminPermission } from '../auth/permissions.enum';
import { Role } from '@prisma/client';

@Controller('locations')
export class LocationsController {
  constructor(private readonly locationsService: LocationsService) {}

  @Get('geocode')
  async forwardGeocode(@Query() query: ForwardGeocodeQueryDto) {
    return this.locationsService.forwardGeocode(query.address);
  }

  @Get('reverse-geocode')
  async reverseGeocode(@Query() query: ReverseGeocodeQueryDto) {
    const lat = parseFloat(query.lat);
    const lng = parseFloat(query.lng);
    return this.locationsService.reverseGeocode(lat, lng);
  }

  @Get('resolve-current-location')
  async resolveCurrentLocation(
    @Query('lat') latStr: string,
    @Query('lng') lngStr: string,
  ) {
    if (!latStr || !lngStr) {
      throw new BadRequestException('lat and lng query parameters are required.');
    }
    const lat = parseFloat(latStr);
    const lng = parseFloat(lngStr);
    return this.locationsService.resolveCurrentLocation(lat, lng);
  }

  @Get('distance')
  async calculateDistance(@Query() query: DistanceQueryDto) {
    const originLat = parseFloat(query.originLat);
    const originLng = parseFloat(query.originLng);
    const destLat = parseFloat(query.destLat);
    const destLng = parseFloat(query.destLng);

    return this.locationsService.estimateRoute(
      originLat,
      originLng,
      destLat,
      destLng,
    );
  }

  @Get('verify-delivery')
  async verifyDelivery(
    @Query('vendorId') vendorId: string,
    @Query('lat') latStr: string,
    @Query('lng') lngStr: string,
  ) {
    if (!vendorId || !latStr || !lngStr) {
      throw new BadRequestException('vendorId, lat, and lng are required.');
    }
    const lat = parseFloat(latStr);
    const lng = parseFloat(lngStr);
    return this.locationsService.verifyDeliveryDistance(vendorId, lat, lng);
  }

  // --- Pickup Hubs Endpoints ---

  @Get('hubs')
  async getPickupHubs(@Query() query: PickupHubQueryDto) {
    return this.locationsService.getPickupHubs(query);
  }

  @Get('vendors/me/hubs')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getMyHubs(@Req() req: any) {
    return this.locationsService.getVendorPickupHubs(req.user.userId);
  }

  @Post('hubs')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR, Role.ADMIN)
  async createHub(@Req() req: any, @Body() dto: CreatePickupHubDto) {
    const isAdmin = req.user?.role === Role.ADMIN;
    return this.locationsService.createPickupHub(req.user.userId, dto, isAdmin);
  }

  @Patch('hubs/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR, Role.ADMIN)
  async updateHub(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdatePickupHubDto,
  ) {
    const isAdmin = req.user?.role === Role.ADMIN;
    return this.locationsService.updatePickupHub(req.user.userId, id, dto, isAdmin);
  }

  @Delete('hubs/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR, Role.ADMIN)
  async deleteHub(@Req() req: any, @Param('id') id: string) {
    const isAdmin = req.user?.role === Role.ADMIN;
    return this.locationsService.deletePickupHub(req.user.userId, id, isAdmin);
  }

  // --- Supported Cities Public & Admin Endpoints ---

  @Get('cities')
  async getSupportedCities() {
    return this.locationsService.adminGetSupportedCities(false);
  }

  @Get('admin/cities')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_READ)
  async adminGetCities(@Query('all') all?: string) {
    const includeInactive = all === 'true';
    return this.locationsService.adminGetSupportedCities(includeInactive);
  }

  @Post('admin/cities')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async adminCreateCity(@Req() req: any, @Body() dto: CreateSupportedCityDto) {
    const adminUserId = req.user?.userId || req.user?.id;
    return this.locationsService.adminCreateSupportedCity(adminUserId, dto);
  }

  @Patch('admin/cities/:id')
  @UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
  @Roles(Role.ADMIN)
  @RequirePermissions(AdminPermission.SYSTEM_CONFIG_WRITE)
  async adminUpdateCity(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateSupportedCityDto,
  ) {
    const adminUserId = req.user?.userId || req.user?.id;
    return this.locationsService.adminUpdateSupportedCity(adminUserId, id, dto);
  }

  @Get('admin/overview')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminOverview(@Query('city') city?: string) {
    return this.locationsService.getOperationalLocationsOverview(city);
  }
}
