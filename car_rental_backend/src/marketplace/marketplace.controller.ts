import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Req,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { MarketplaceSearchService } from './marketplace-search.service';
import { MarketplaceQuoteService } from './marketplace-quote.service';
import { PromotionEngineService } from './promotion-engine.service';
import { AncillaryProductsService } from './ancillary-products.service';
import { CheckoutOrchestratorService } from './checkout-orchestrator.service';
import { CancellationPreviewService } from './cancellation-preview.service';
import { MarketplaceSearchQueryDto } from './dto/marketplace-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CarCategory } from '@prisma/client';
import { RateLimit } from '../common/decorators/rate-limit.decorator';

@Controller('marketplace')
export class MarketplaceController {
  constructor(
    private readonly searchService: MarketplaceSearchService,
    private readonly quoteService: MarketplaceQuoteService,
    private readonly promotionEngine: PromotionEngineService,
    private readonly ancillaryService: AncillaryProductsService,
    private readonly checkoutService: CheckoutOrchestratorService,
    private readonly cancellationPreview: CancellationPreviewService,
  ) {}

  /**
   * 1. SEARCH MARKETPLACE (GET / POST)
   */
  @RateLimit({ limit: 60, ttlSeconds: 60 })
  @Get('search')
  async searchGet(@Query() query: MarketplaceSearchQueryDto) {
    return this.searchService.searchMarketplace(query);
  }

  @RateLimit({ limit: 60, ttlSeconds: 60 })
  @Post('search')
  async searchPost(@Body() query: MarketplaceSearchQueryDto) {
    return this.searchService.searchMarketplace(query);
  }

  /**
   * 2. DISCOVER ANCILLARY PRODUCTS
   */
  @Get('ancillaries')
  async getAncillaries(
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
    @Query('vehicleClass') vehicleClass?: CarCategory,
  ) {
    return this.ancillaryService.getEligibleAncillaries({
      vendorId,
      branchId,
      vehicleClass,
    });
  }

  /**
   * 3. EVALUATE PROMOTIONS / COUPONS
   */
  @Post('promotions/evaluate')
  async evaluatePromotion(
    @Body()
    body: {
      code: string;
      vendorId: string;
      branchId?: string;
      vehicleClass: CarCategory;
      subtotal: number;
      durationDays: number;
      startDate: string;
      endDate: string;
    },
    @Req() req: any,
  ) {
    return this.promotionEngine.evaluatePromotion(body.code, {
      customerId: req.user?.userId,
      vendorId: body.vendorId,
      branchId: body.branchId,
      vehicleClass: body.vehicleClass,
      subtotal: body.subtotal,
      durationDays: body.durationDays,
      startDate: new Date(body.startDate),
      endDate: new Date(body.endDate),
    });
  }

  /**
   * 4. AUTHORITATIVE QUOTE CREATION & REFRESH
   */
  @Post('quotes')
  async createQuote(@Body() body: any, @Req() req: any) {
    return this.quoteService.createQuote({
      ...body,
      customerId: req.user?.userId || body.customerId,
    });
  }

  @Get('quotes/:quoteId')
  async getQuote(@Param('quoteId') quoteId: string) {
    return this.quoteService.getVerifiedQuote(quoteId);
  }

  @Post('quotes/:quoteId/refresh')
  async refreshQuote(@Param('quoteId') quoteId: string, @Req() req: any) {
    return this.quoteService.refreshQuote(quoteId, req.user?.userId);
  }

  /**
   * 5. CHECKOUT ORCHESTRATION
   */
  @UseGuards(JwtAuthGuard)
  @Post('checkout/session')
  async createCheckoutSession(
    @Body() body: { quoteId: string; customerId?: string },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.createCheckoutSession(body.quoteId, customerId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('checkout/:sessionId/addons')
  async configureAddons(
    @Param('sessionId') sessionId: string,
    @Body() body: { addons: any[]; customerId?: string },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.configureAddons(sessionId, customerId, body.addons || []);
  }

  @UseGuards(JwtAuthGuard)
  @Post('checkout/:sessionId/driver')
  async submitDriver(
    @Param('sessionId') sessionId: string,
    @Body() body: { driver: any; customer?: any; customerId?: string },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.submitDriverAndCustomerDetails(
      sessionId,
      customerId,
      body.driver,
      body.customer,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Get('checkout/:sessionId/payment-options')
  async getPaymentOptions(
    @Param('sessionId') sessionId: string,
    @Query('customerId') customerIdQuery?: string,
    @Req() req?: any,
  ) {
    const customerId = req?.user?.userId || customerIdQuery;
    return this.checkoutService.getAvailablePaymentOptions(sessionId, customerId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('checkout/:sessionId/pay')
  async initiatePayment(
    @Param('sessionId') sessionId: string,
    @Body() body: { paymentMethod: string; idempotencyKey?: string; customerId?: string },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.initiatePayment(
      sessionId,
      customerId,
      body.paymentMethod,
      body.idempotencyKey,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('checkout/:sessionId/verify')
  async verifyPayment(
    @Param('sessionId') sessionId: string,
    @Body() body: { orderId: string; paymentId: string; signature?: string; customerId?: string },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.verifyAndConfirmPayment(sessionId, customerId, {
      orderId: body.orderId,
      paymentId: body.paymentId,
      signature: body.signature,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Post('checkout/:sessionId/failover')
  async handlePaymentFailover(
    @Param('sessionId') sessionId: string,
    @Body()
    body: {
      providerId: string;
      errorCode?: string;
      errorMessage?: string;
      dispatchedToGateway?: boolean;
      customerId?: string;
    },
    @Req() req: any,
  ) {
    const customerId = req.user?.userId || body.customerId;
    return this.checkoutService.handlePaymentFailure(sessionId, customerId, body);
  }

  /**
   * 6. CANCELLATION PREVIEW
   */
  @Get('cancellation-preview/:bookingId')
  async previewCancellation(@Param('bookingId') bookingId: string) {
    return this.cancellationPreview.previewCancellation(bookingId);
  }
}
