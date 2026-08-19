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
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { VendorsService } from './vendors.service';
import { CarsService } from '../cars/cars.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role, TripType } from '@prisma/client';
import { VendorsQueryDto } from './dto/vendors-query.dto';
import { UpdateVendorDto } from './dto/update-vendor.dto';
import { UpdateVendorStatusDto } from './dto/update-vendor-status.dto';
import { PaginationDto } from '../common/pagination.dto';
import { CreateCarDto } from '../cars/dto/create-car.dto';
import { UpdateCarDto } from '../cars/dto/update-car.dto';
import { UpdateAvailabilityDto } from '../cars/dto/update-availability.dto';
import { UpdateBlockedDatesDto } from '../cars/dto/update-blocked-dates.dto';
import { CreateMileagePackageDto } from '../cars/dto/create-mileage-package.dto';
import { UpdateMileagePackageDto } from '../cars/dto/update-mileage-package.dto';
import { JwtService } from '@nestjs/jwt';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UpdateDocumentStatusDto } from './dto/update-document-status.dto';
import { redactVendor } from '../common/vendor-redactor.util';

import { ConfigService } from '@nestjs/config';

@Controller('vendors')
export class VendorsController {
  constructor(
    private readonly vendorsService: VendorsService,
    private readonly carsService: CarsService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  @Get()
  async findAll(@Req() req: any, @Query() query: VendorsQueryDto) {
    const isAdmin = await this.getIsAdmin(req);
    const result = await this.vendorsService.findAll(query);
    result.data = result.data.map((vendor) =>
      redactVendor(vendor, { isAdmin }),
    );
    return result;
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me')
  async findMe(@Req() req: any) {
    const vendor = await this.vendorsService.findByUserId(req.user.userId);
    return redactVendor(vendor, { isOwner: true });
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Patch('me')
  async updateMe(@Req() req: any, @Body() dto: UpdateVendorDto) {
    return this.vendorsService.updateMe(req.user.userId, dto);
  }

  // --- Multi-Branch Routes ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Post('me/branches')
  @HttpCode(HttpStatus.CREATED)
  async createBranch(@Req() req: any, @Body() dto: any) {
    return this.vendorsService.createBranch(req.user.userId, dto);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/branches')
  async getMyBranches(@Req() req: any) {
    return this.vendorsService.getMyBranches(req.user.userId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/analytics')
  async getVendorAnalytics(@Req() req: any) {
    return this.vendorsService.getVendorAnalytics(req.user.userId);
  }

  // --- Vendor own fleet operations (Must be defined before wildcard GET :id routes) ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/cars')
  async findVendorCars(@Req() req: any) {
    return this.carsService.findVendorCars(req.user.userId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Post('me/cars')
  @HttpCode(HttpStatus.CREATED)
  async createCar(@Req() req: any, @Body() dto: CreateCarDto) {
    return this.carsService.createCar(req.user.userId, dto);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Patch('me/cars/:id')
  async updateCar(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateCarDto,
  ) {
    return this.carsService.updateCar(id, req.user.userId, dto);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Patch('me/cars/:id/availability')
  async updateAvailability(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateAvailabilityDto,
  ) {
    return this.carsService.updateAvailability(
      id,
      req.user.userId,
      dto.isAvailable,
    );
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Patch('me/cars/:id/blocked-dates')
  async updateBlockedDates(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateBlockedDatesDto,
  ) {
    return this.carsService.updateBlockedDates(
      id,
      req.user.userId,
      dto.blockedDates,
    );
  }

  // --- Vendor Mileage Packages Management ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/cars/:carId/mileage-packages')
  async getMyCarMileagePackages(
    @Param('carId') carId: string,
    @Query('tripType') tripType?: TripType,
  ) {
    return this.carsService.getCarMileagePackages(carId, tripType, false);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Post('me/cars/:carId/mileage-packages')
  @HttpCode(HttpStatus.CREATED)
  async createMileagePackage(
    @Param('carId') carId: string,
    @Req() req: any,
    @Body() dto: CreateMileagePackageDto,
  ) {
    return this.carsService.createCarMileagePackage(
      req.user.userId,
      carId,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Patch('me/cars/:carId/mileage-packages/:packageId')
  async updateMileagePackage(
    @Param('carId') carId: string,
    @Param('packageId') packageId: string,
    @Req() req: any,
    @Body() dto: UpdateMileagePackageDto,
  ) {
    return this.carsService.updateCarMileagePackage(
      req.user.userId,
      carId,
      packageId,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Delete('me/cars/:carId/mileage-packages/:packageId')
  async deleteMileagePackage(
    @Param('carId') carId: string,
    @Param('packageId') packageId: string,
    @Req() req: any,
  ) {
    return this.carsService.deleteCarMileagePackage(
      req.user.userId,
      carId,
      packageId,
    );
  }

  // --- Wildcard & Param based routes ---

  @Get(':id')
  async findOne(@Req() req: any, @Param('id') id: string) {
    const isAdmin = await this.getIsAdmin(req);
    const vendor = await this.vendorsService.findOne(id);
    return redactVendor(vendor, { isAdmin });
  }

  @Get(':id/cars')
  async findCars(@Param('id') id: string) {
    return this.vendorsService.findCars(id);
  }

  @Get(':id/reviews')
  async findReviews(@Param('id') id: string, @Query() query: PaginationDto) {
    return this.vendorsService.findReviews(id, query);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch(':id/status')
  async updateStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateVendorStatusDto,
  ) {
    return this.vendorsService.updateStatus(id, dto, req.user.userId);
  }

  // --- Vendor document operations ---

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/cars/:id/documents')
  async getCarDocuments(@Req() req: any, @Param('id') id: string) {
    return this.vendorsService.getCarDocuments(req.user.userId, id);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Post('me/documents')
  @HttpCode(HttpStatus.CREATED)
  async addDocument(@Req() req: any, @Body() dto: CreateDocumentDto) {
    return this.vendorsService.addDocument(
      req.user.userId,
      dto.type,
      dto.fileUrl,
      dto.carId,
      dto.expiresAt,
    );
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.VENDOR)
  @Get('me/documents')
  async getDocuments(@Req() req: any) {
    return this.vendorsService.getDocuments(req.user.userId);
  }

  // --- Helper Methods ---

  private async getIsAdmin(req: any): Promise<boolean> {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return false;
    }
    const token = authHeader.split(' ')[1];
    const secret =
      this.configService.get<string>('JWT_ACCESS_SECRET') ||
      'dev_access_secret_key_change_me_12345!';
    try {
      const verified: any = await this.jwtService.verifyAsync(token, {
        secret,
      });
      return (
        verified &&
        (verified.role === Role.ADMIN || verified.role === Role.SUPPORT_AGENT)
      );
    } catch {
      return false;
    }
  }
}
