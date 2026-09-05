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
  HttpStatus,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { InspectionsService } from './inspections.service';
import { HandoverOtpService } from './handover-otp.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { UpdateBookingStatusDto } from './dto/update-booking-status.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { FlagDisputeDto } from './dto/flag-dispute.dto';
import { CreateInspectionDto } from './dto/create-inspection.dto';
import { SendHandoverOtpDto } from './dto/send-handover-otp.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { BookingStatus, Role, TripType } from '@prisma/client';
import { PaginationDto } from '../common/pagination.dto';
import { Optional } from '@nestjs/common';
import { BookingLifecycleService } from './booking-lifecycle.service';
import { BookingOutboxService } from './booking-outbox.service';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class BookingsController {
  constructor(
    private readonly bookingsService: BookingsService,
    private readonly inspectionsService: InspectionsService,
    private readonly handoverOtpService: HandoverOtpService,
    @Optional() private readonly lifecycleService?: BookingLifecycleService,
    @Optional() private readonly outboxService?: BookingOutboxService,
  ) {}

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
    return this.bookingsService.getBookingsForCustomer(
      req.user.userId,
      status,
      pagination,
    );
  }

  // 2. GET bookings for vendor fleet (VENDOR)
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
    return this.bookingsService.getBookingsForVendor(
      req.user.userId,
      status,
      pagination,
    );
  }

  // 3. GET all bookings (ADMIN, SUPPORT_AGENT) with advanced filters
  @Get('admin/bookings')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
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
      pagination,
    );
  }

  // 4. POST create booking (CUSTOMER)
  @Post('bookings')
  @Roles(Role.CUSTOMER)
  async createBooking(@Req() req: any, @Body() dto: CreateBookingDto) {
    return this.bookingsService.createBooking(req.user.userId, dto);
  }

  // 5. GET cancellation preview (CUSTOMER, VENDOR, ADMIN, SUPPORT_AGENT)
  @Get('bookings/:id/cancellation-preview')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN, Role.SUPPORT_AGENT)
  async getCancellationPreview(@Param('id') id: string, @Req() req: any) {
    return this.bookingsService.getCancellationPreview(id, req.user);
  }

  // 6. POST cancel booking (CUSTOMER)
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

  // 7. POST flag dispute (ADMIN)
  @Post('admin/bookings/:id/flag-dispute')
  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async flagDispute(@Param('id') id: string, @Body() dto: FlagDisputeDto) {
    return this.bookingsService.flagDispute(id, dto.note);
  }

  // 8. POST resolve dispute (ADMIN)
  @Post('admin/bookings/:id/resolve-dispute')
  @Roles(Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async resolveDispute(@Param('id') id: string) {
    return this.bookingsService.resolveDispute(id);
  }

  // 9. POST create/update vehicle inspection (VENDOR, ADMIN)
  @Post('bookings/:id/inspections')
  @Roles(Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async upsertInspection(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: CreateInspectionDto,
  ) {
    return this.inspectionsService.upsertInspection(id, dto, req.user);
  }

  // 10. GET vehicle inspections (CUSTOMER, VENDOR, ADMIN, SUPPORT_AGENT)
  @Get('bookings/:id/inspections')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN, Role.SUPPORT_AGENT)
  async getInspections(@Param('id') id: string, @Req() req: any) {
    return this.inspectionsService.getInspections(id, req.user);
  }

  // 11. POST send handover OTP (CUSTOMER, VENDOR, ADMIN)
  @Post('bookings/:id/handover-otp/send')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async sendHandoverOtp(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: SendHandoverOtpDto,
  ) {
    return this.handoverOtpService.generateAndSendOtp(
      id,
      dto.otpType,
      req.user,
    );
  }

  // 12. PATCH override status (ADMIN)
  @Patch('admin/bookings/:id/override-status')
  @Roles(Role.ADMIN)
  async overrideStatus(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateBookingStatusDto,
  ) {
    return this.bookingsService.updateStatus(
      id,
      dto.status,
      req.user,
      dto.reason,
      dto.handoverOtp,
    );
  }

  // 13. PATCH status (VENDOR or ADMIN)
  @Patch('bookings/:id/status')
  @Roles(Role.VENDOR, Role.ADMIN)
  async updateStatus(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: UpdateBookingStatusDto,
    @Query('reason') reason?: string,
  ) {
    return this.bookingsService.updateStatus(
      id,
      dto.status,
      req.user,
      dto.reason || reason,
      dto.handoverOtp,
    );
  }

  // 14. GET booking detail (CUSTOMER, VENDOR, ADMIN, SUPPORT_AGENT)
  @Get('bookings/:id')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN, Role.SUPPORT_AGENT)
  async getBookingDetail(@Param('id') id: string, @Req() req: any) {
    return this.bookingsService.getBookingById(id, req.user);
  }

  // 15. POST confirm booking (VENDOR, ADMIN)
  @Post('bookings/:id/confirm')
  @Roles(Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async confirmBooking(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body?: { reason?: string },
  ) {
    if (this.lifecycleService) {
      return this.lifecycleService.confirmBooking(
        id,
        req.user.userId,
        req.user.role,
        body?.reason,
      );
    }
    return this.bookingsService.updateStatus(
      id,
      BookingStatus.CONFIRMED,
      req.user,
      body?.reason,
    );
  }

  // 16. POST mark ready for handover (VENDOR, ADMIN)
  @Post('bookings/:id/ready-for-handover')
  @Roles(Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async markReadyForHandover(@Param('id') id: string, @Req() req: any) {
    if (this.lifecycleService) {
      return this.lifecycleService.markReadyForHandover(
        id,
        req.user.userId,
        req.user.role,
      );
    }
    return this.bookingsService.updateStatus(
      id,
      BookingStatus.HANDOVER_READY,
      req.user,
    );
  }

  // 17. POST start rental (VENDOR, ADMIN)
  @Post('bookings/:id/start-rental')
  @Roles(Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async startRental(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body?: { handoverOtp?: string; reason?: string },
  ) {
    if (this.lifecycleService) {
      return this.lifecycleService.startRental(
        id,
        req.user.userId,
        req.user.role,
        body?.handoverOtp,
        body?.reason,
      );
    }
    return this.bookingsService.updateStatus(
      id,
      BookingStatus.ONGOING,
      req.user,
      body?.reason,
      body?.handoverOtp,
    );
  }

  // 18. POST initiate return (CUSTOMER, VENDOR, ADMIN)
  @Post('bookings/:id/initiate-return')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async initiateReturn(@Param('id') id: string, @Req() req: any) {
    if (this.lifecycleService) {
      return this.lifecycleService.initiateReturn(
        id,
        req.user.userId,
        req.user.role,
      );
    }
    return this.bookingsService.updateStatus(
      id,
      BookingStatus.RETURN_PENDING,
      req.user,
    );
  }

  // 19. POST complete booking (VENDOR, ADMIN)
  @Post('bookings/:id/complete')
  @Roles(Role.VENDOR, Role.ADMIN)
  @HttpCode(HttpStatus.OK)
  async completeBooking(
    @Param('id') id: string,
    @Req() req: any,
    @Body() body?: { handoverOtp?: string; reason?: string },
  ) {
    if (this.lifecycleService) {
      return this.lifecycleService.completeBooking(
        id,
        req.user.userId,
        req.user.role,
        body?.handoverOtp,
        body?.reason,
      );
    }
    return this.bookingsService.updateStatus(
      id,
      BookingStatus.COMPLETED,
      req.user,
      body?.reason,
      body?.handoverOtp,
    );
  }

  // 20. GET lifecycle audit history (ADMIN, SUPPORT_AGENT)
  @Get('admin/bookings/:id/lifecycle-history')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getLifecycleHistory(@Param('id') id: string) {
    if (this.outboxService) {
      return this.outboxService.getLifecycleHistory(id);
    }
    return [];
  }
}
