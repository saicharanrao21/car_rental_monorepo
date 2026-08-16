import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { TripExtensionsService } from './trip-extensions.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@Controller('bookings/:id/extensions')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TripExtensionsController {
  constructor(private readonly extensionsService: TripExtensionsService) {}

  @Post('quote')
  async getQuote(
    @Param('id') bookingId: string,
    @Body('requestedEndDate') requestedEndDate: string,
    @Request() req: any,
  ) {
    return this.extensionsService.getQuote(bookingId, requestedEndDate, req.user);
  }

  @Post()
  async createExtension(
    @Param('id') bookingId: string,
    @Body('requestedEndDate') requestedEndDate: string,
    @Request() req: any,
  ) {
    return this.extensionsService.createExtension(
      bookingId,
      requestedEndDate,
      req.user.userId,
    );
  }

  @Post(':extId/verify')
  async verifyPayment(
    @Param('id') bookingId: string,
    @Param('extId') extId: string,
    @Body()
    paymentDetails: {
      razorpayOrderId: string;
      razorpayPaymentId: string;
      razorpaySignature: string;
    },
    @Request() req: any,
  ) {
    return this.extensionsService.verifyExtensionPayment(
      bookingId,
      extId,
      paymentDetails,
      req.user.userId,
    );
  }

  @Get()
  async getExtensions(@Param('id') bookingId: string) {
    return this.extensionsService.getExtensionsForBooking(bookingId);
  }
}
