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
import {
  CreateVendorLocationDto,
  UpdateVendorLocationDto,
  UpdateVendorDeliveryPolicyDto,
  CalculateDeliveryQuoteDto,
  UpdateLocationMatrixDto,
  CreateLocationExceptionDto,
  VendorLocationStatusEnum,
} from './dto/vendor-location-operations.dto';
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

  // --- Phase 29.11 & 29.12 Vendor Location Operations & Delivery Endpoints ---

  @Get('vendors/me/locations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorLocations(@Req() req: any) {
    return this.locationsService.getVendorLocations(req.user.userId);
  }

  @Post('vendors/me/locations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async createVendorLocation(@Req() req: any, @Body() dto: CreateVendorLocationDto) {
    return this.locationsService.createVendorLocation(req.user.userId, dto);
  }

  @Get('vendors/me/locations/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorLocationById(@Req() req: any, @Param('id') id: string) {
    return this.locationsService.getVendorLocationById(req.user.userId, id);
  }

  @Put('vendors/me/locations/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async putVendorLocation(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateVendorLocationDto,
  ) {
    return this.locationsService.updateVendorLocation(req.user.userId, id, dto);
  }

  @Patch('vendors/me/locations/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async updateVendorLocation(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateVendorLocationDto,
  ) {
    return this.locationsService.updateVendorLocation(req.user.userId, id, dto);
  }

  @Delete('vendors/me/locations/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async deleteVendorLocation(@Req() req: any, @Param('id') id: string) {
    return this.locationsService.deleteVendorLocation(req.user.userId, id);
  }

  // Location Exceptions Endpoints
  @Post('vendors/me/locations/:id/exceptions')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async createLocationException(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: CreateLocationExceptionDto,
  ) {
    return this.locationsService.createLocationException(req.user.userId, id, dto);
  }

  @Get('vendors/me/locations/:id/exceptions')
  async getLocationExceptions(@Param('id') id: string) {
    return this.locationsService.getLocationExceptions(id);
  }

  @Delete('vendors/me/exceptions/:exceptionId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async deleteLocationException(
    @Req() req: any,
    @Param('exceptionId') exceptionId: string,
  ) {
    return this.locationsService.deleteLocationException(req.user.userId, exceptionId);
  }

  // Delivery Policy Endpoints (Supports both /policy and /delivery-policy, GET, PUT, PATCH)
  @Get('vendors/me/policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorPolicy(@Req() req: any) {
    return this.locationsService.getVendorDeliveryPolicy(req.user.userId);
  }

  @Get('vendors/me/delivery-policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorDeliveryPolicy(@Req() req: any) {
    return this.locationsService.getVendorDeliveryPolicy(req.user.userId);
  }

  @Put('vendors/me/policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async putVendorPolicy(
    @Req() req: any,
    @Body() dto: UpdateVendorDeliveryPolicyDto,
  ) {
    return this.locationsService.updateVendorDeliveryPolicy(req.user.userId, dto);
  }

  @Patch('vendors/me/policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async patchVendorPolicy(
    @Req() req: any,
    @Body() dto: UpdateVendorDeliveryPolicyDto,
  ) {
    return this.locationsService.updateVendorDeliveryPolicy(req.user.userId, dto);
  }

  @Put('vendors/me/delivery-policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async putVendorDeliveryPolicy(
    @Req() req: any,
    @Body() dto: UpdateVendorDeliveryPolicyDto,
  ) {
    return this.locationsService.updateVendorDeliveryPolicy(req.user.userId, dto);
  }

  @Patch('vendors/me/delivery-policy')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async updateVendorDeliveryPolicy(
    @Req() req: any,
    @Body() dto: UpdateVendorDeliveryPolicyDto,
  ) {
    return this.locationsService.updateVendorDeliveryPolicy(req.user.userId, dto);
  }

  // Matrix Endpoints
  @Get('vendors/me/matrix')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorLocationMatrix(@Req() req: any) {
    return this.locationsService.getVendorLocationMatrix(req.user.userId);
  }

  @Put('vendors/me/matrix')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async putVendorLocationMatrix(
    @Req() req: any,
    @Body() dto: UpdateLocationMatrixDto,
  ) {
    return this.locationsService.updateVendorLocationMatrix(req.user.userId, dto);
  }

  @Patch('vendors/me/matrix')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async updateVendorLocationMatrix(
    @Req() req: any,
    @Body() dto: UpdateLocationMatrixDto,
  ) {
    return this.locationsService.updateVendorLocationMatrix(req.user.userId, dto);
  }

  @Get('vendors/me/operations-summary')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  async getVendorOperationsSummary(@Req() req: any) {
    return this.locationsService.getVendorLocationOperationsSummary(req.user.userId);
  }

  @Get('public/catalog')
  async getPublicCatalog(@Query('city') city?: string) {
    return this.locationsService.getPublicLocationCatalog(city);
  }

  @Get('public-catalog')
  async getPublicLocationCatalog(@Query('city') city?: string) {
    return this.locationsService.getPublicLocationCatalog(city);
  }

  @Post('quote')
  async getQuote(@Body() dto: CalculateDeliveryQuoteDto) {
    return this.locationsService.calculateDeliveryQuote(dto);
  }

  @Post('eligibility')
  async checkEligibility(@Body() dto: CalculateDeliveryQuoteDto) {
    return this.locationsService.calculateDeliveryQuote(dto);
  }

  @Post('calculate-delivery-quote')
  async calculateDeliveryQuote(@Body() dto: CalculateDeliveryQuoteDto) {
    return this.locationsService.calculateDeliveryQuote(dto);
  }

  // --- Pickup Hubs Legacy Endpoints ---

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

  @Get('admin/locations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async adminGetLocations(
    @Query('city') city?: string,
    @Query('status') status?: string,
    @Query('type') type?: string,
  ) {
    return this.locationsService.adminGetLocations({ city, status, type });
  }

  @Get('admin/locations/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async adminGetLocationById(@Param('id') id: string) {
    return this.locationsService.adminGetLocationById(id);
  }

  @Patch('admin/locations/:id/status')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async adminUpdateLocationStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body('status') status: VendorLocationStatusEnum,
  ) {
    const adminUserId = req.user?.userId || req.user?.id;
    return this.locationsService.adminUpdateLocationStatus(adminUserId, id, status);
  }
}

