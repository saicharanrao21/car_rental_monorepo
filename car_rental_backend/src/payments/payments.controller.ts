import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  Req,
  Headers,
  BadRequestException,
} from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { VerifyPaymentDto } from './dto/verify-payment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { RateLimiterGuard } from '../common/guards/rate-limiter.guard';
import { RateLimit } from '../common/decorators/rate-limit.decorator';

@Controller('payments')
@UseGuards(RateLimiterGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  // 1. POST /payments/create-order (CUSTOMER)
  @Post('create-order')
  @RateLimit({ limit: 15, ttlSeconds: 60 })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CUSTOMER)
  async createOrder(@Req() req: any, @Body() dto: CreateOrderDto) {
    return this.paymentsService.createOrder(dto.bookingId, req.user.userId);
  }

  // 2. POST /payments/verify (CUSTOMER)
  @Post('verify')
  @RateLimit({ limit: 15, ttlSeconds: 60 })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CUSTOMER)
  async verifyPayment(@Req() req: any, @Body() dto: VerifyPaymentDto) {
    return this.paymentsService.verifyPayment(dto, req.user.userId);
  }

  // 3. POST /payments/webhook (PUBLIC)
  @Post('webhook')
  @RateLimit({ limit: 120, ttlSeconds: 60 })
  async handleWebhook(
    @Req() req: any,
    @Headers('x-razorpay-signature') signature: string,
  ) {
    const rawBody = req.rawBody;

    if (!rawBody) {
      throw new BadRequestException('Raw request body is required');
    }

    if (!signature) {
      throw new BadRequestException('Webhook signature is missing');
    }

    return this.paymentsService.handleWebhook(rawBody, signature);
  }

  // 4. GET /payments/:bookingId (CUSTOMER who owns it, ADMIN, or SUPPORT_AGENT)
  @Get(':bookingId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.CUSTOMER, Role.ADMIN, Role.SUPPORT_AGENT)
  async getPaymentStatus(
    @Req() req: any,
    @Param('bookingId') bookingId: string,
  ) {
    return this.paymentsService.getPaymentByBookingId(bookingId, req.user);
  }
}
