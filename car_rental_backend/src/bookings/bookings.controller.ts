import { 
  Controller, 
  Get, 
  Post, 
  Patch, 
  Body, 
  Param, 
  Query, 
  UseGuards, 
  Req,
  HttpCode,
  HttpStatus
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { UpdateBookingStatusDto } from './dto/update-booking-status.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { FlagDisputeDto } from './dto/flag-dispute.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { BookingStatus, Role, TripType } from '@prisma/client';
import { PaginationDto } from '../common/pagination.dto';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  // 1. GET own bookings (CUSTOMER)
  @Get('bookings/me')
  @Roles(Role.CUSTOMER)
  async getMyBookings(
    @Req() req: any,
    @Query('status') status?: BookingStatus,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = Number(page);
    if (limit) pagination.limit = Number(limit);
    return this.bookingsService.getBookingsForCustomer(req.user.userId, status, pagination);
  }

  // 2. GET vendor's own bookings (VENDOR)
  @Get('vendors/me/bookings')
  @Roles(Role.VENDOR)
  async getVendorBookings(
    @Req() req: any,
    @Query('status') status?: BookingStatus,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = Number(page);
    if (limit) pagination.limit = Number(limit);
    return this.bookingsService.getBookingsForVendor(req.user.userId, status, pagination);
  }

  // 3. GET all bookings (ADMIN) with advanced filters
  @Get('admin/bookings')
  @Roles(Role.ADMIN)
  async getAdminBookings(
    @Query('city') city?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('tripType') tripType?: TripType,
    @Query('status') status?: BookingStatus,
    @Query('vendorId') vendorId?: string,
    @Query('carType') carType?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = Number(page);
    if (limit) pagination.limit = Number(limit);

    return this.bookingsService.getBookingsForAdmin(
      { city, startDate, endDate, tripType, status, vendorId, carType },
      pagination
    );
  }

  // 4. POST create booking (CUSTOMER)
  @Post('bookings')
  @Roles(Role.CUSTOMER)
  async createBooking(@Req() req: any, @Body() dto: CreateBookingDto) {
    return this.bookingsService.createBooking(req.user.userId, dto);
  }

  // 5. POST cancel booking (CUSTOMER)
  @Post('bookings/:id/cancel')
  @Roles(Role.CUSTOMER)
  @HttpCode(HttpStatus.OK)
  async cancelBooking(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: CancelBookingDto,
  ) {
    return this.bookingsService.cancelBooking(id, req.user.userId, dto.reason);
  }

  // 6. POST flag dispute (ADMIN)
  @Post('admin/bookings/:id/flag-dispute')
  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async flagDispute(@Param('id') id: string, @Body() dto: FlagDisputeDto) {
    return this.bookingsService.flagDispute(id, dto.note);
  }

  // 7. POST resolve dispute (ADMIN)
  @Post('admin/bookings/:id/resolve-dispute')
  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async resolveDispute(@Param('id') id: string) {
    return this.bookingsService.resolveDispute(id);
  }

  // 8. PATCH override status (ADMIN)
  @Patch('admin/bookings/:id/override-status')
  @Roles(Role.ADMIN)
  async overrideStatus(@Param('id') id: string, @Body() dto: UpdateBookingStatusDto) {
    return this.bookingsService.updateStatus(id, dto.status, { userId: 'admin', role: Role.ADMIN });
  }

  // 9. PATCH status (VENDOR or ADMIN)
  @Patch('bookings/:id/status')
  @Roles(Role.VENDOR, Role.ADMIN)
  async updateStatus(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateBookingStatusDto,
    @Query('reason') reason?: string,
  ) {
    return this.bookingsService.updateStatus(id, dto.status, req.user, reason);
  }

  // 10. GET booking detail (CUSTOMER, VENDOR, ADMIN)
  @Get('bookings/:id')
  async getBookingDetail(@Param('id') id: string, @Req() req: any) {
    return this.bookingsService.getBookingById(id, req.user);
  }
}
