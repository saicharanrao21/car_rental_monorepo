import {
  Controller,
  Get,
  Query,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { LocationsService } from './locations.service';
import {
  ForwardGeocodeQueryDto,
  ReverseGeocodeQueryDto,
} from './dto/geocode-query.dto';
import { DistanceQueryDto } from './dto/distance-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
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

  @Get('admin/overview')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  async getAdminOverview(@Query('city') city?: string) {
    return this.locationsService.getOperationalLocationsOverview(city);
  }
}
