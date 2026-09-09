import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RentalPricingResolutionService } from '../pricing/rental-pricing-resolution.service';
import { PromotionEngineService } from './promotion-engine.service';
import { AncillaryProductsService, AncillarySelectionInput } from './ancillary-products.service';
import {
  CarCategory,
  TripType,
  QuoteStatus,
  QuoteLineItemType,
  Prisma,
} from '@prisma/client';
import * as crypto from 'crypto';

export interface CreateMarketplaceQuoteInput {
  customerId?: string;
  vendorId: string;
  branchId?: string;
  returnBranchId?: string;
  vehicleClass: CarCategory;
  carId: string;
  startDate: string | Date;
  endDate: string | Date;
  tripType?: TripType;
  couponCode?: string;
  ancillaries?: AncillarySelectionInput[];
  deliveryAddress?: string;
  deliveryLatitude?: number;
  deliveryLongitude?: number;
  idempotencyKey?: string;
}

export interface AuthoritativeQuoteSnapshot {
  quoteId: string;
  tenantId: string;
  customerId?: string;
  carId: string;
  vehicleClass: CarCategory;
  tripType: TripType;
  startDate: string;
  endDate: string;
  durationDays: number;
  durationHours: number;
  pricingVersion: string;
  currency: string;
  subtotal: number;
  discountTotal: number;
  feesTotal: number;
  taxTotal: number;
  depositTotal: number;
  totalPayable: number;
  netToVendor: number;
  expiresAt: string;
  status: QuoteStatus;
  integrityChecksum: string;
  lineItems: Array<{
    type: string;
    name: string;
    description?: string;
    rate: number;
    quantity: number;
    amount: number;
    isRefundable: boolean;
  }>;
  appliedRules: string[];
}

@Injectable()
export class MarketplaceQuoteService {
  private readonly logger = new Logger(MarketplaceQuoteService.name);
  public static readonly QUOTE_LOCK_DURATION_MINUTES = 15;

  constructor(
    private readonly prisma: PrismaService,
    private readonly pricingResolution: RentalPricingResolutionService,
    private readonly promotionEngine: PromotionEngineService,
    private readonly ancillaryService: AncillaryProductsService,
  ) {}

  /**
   * Creates an authoritative 15-minute locked quote with cryptographic checksum integrity.
   * Guarantees zero price drift from search to checkout.
   */
  async createQuote(input: CreateMarketplaceQuoteInput): Promise<AuthoritativeQuoteSnapshot> {
    const start = new Date(input.startDate);
    const end = new Date(input.endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime()) || start >= end) {
      throw new BadRequestException('Invalid start or end date for quote creation.');
    }

    // 1. Idempotency check: if existing active quote found with same key, return it
    if (input.idempotencyKey) {
      const existing = await this.prisma.bookingQuote.findUnique({
        where: { idempotencyKey: input.idempotencyKey },
        include: { lineItems: { orderBy: { displayOrder: 'asc' } } },
      });
      if (existing && existing.status === QuoteStatus.ACTIVE && existing.expiresAt > new Date()) {
        return this.mapToSnapshot(existing);
      }
    }

    // 2. Fetch car to verify class and vendor
    const car = await this.prisma.car.findUnique({
      where: { id: input.carId },
      include: { vendor: true, pickupHub: true },
    });
    if (!car) {
      throw new NotFoundException(`Vehicle with ID '${input.carId}' not found.`);
    }

    const durationMs = end.getTime() - start.getTime();
    const durationDays = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60 * 24)));
    const durationHours = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60)));

    // 3. Resolve hierarchical pricing via RentalPricingResolutionService
    const resolvedPricing = await this.pricingResolution.resolvePricing({
      vendorId: input.vendorId || car.vendorId,
      branchId: input.branchId || car.pickupHubId || undefined,
      returnBranchId: input.returnBranchId,
      vehicleClass: input.vehicleClass || car.type,
      carId: car.id,
      startDate: start,
      endDate: end,
      tripType: input.tripType || TripType.SELF_DRIVE,
    });

    let subtotal = resolvedPricing.subtotal;
    let discountTotal = resolvedPricing.discountTotal;
    let feesTotal = resolvedPricing.feesTotal;
    let taxTotal = resolvedPricing.taxTotal;
    const depositTotal = resolvedPricing.depositTotal;
    let netToVendor = resolvedPricing.netToVendor;

    const lineItemsToPersist: Array<{
      type: QuoteLineItemType;
      name: string;
      description?: string;
      rate: number;
      quantity: number;
      amount: number;
      isRefundable: boolean;
      displayOrder: number;
    }> = resolvedPricing.lineItems.map((item, idx) => ({
      type: item.category === 'BASE' ? QuoteLineItemType.BASE_RENTAL :
            item.category === 'TAX' ? QuoteLineItemType.GST :
            item.category === 'DEPOSIT' ? QuoteLineItemType.SECURITY_DEPOSIT :
            item.category === 'DISCOUNT' ? QuoteLineItemType.DURATION_DISCOUNT :
            QuoteLineItemType.PLATFORM_FEE,
      name: item.name,
      description: item.explanation,
      rate: item.rate,
      quantity: item.quantity,
      amount: item.amount,
      isRefundable: item.isRefundable,
      displayOrder: idx + 1,
    }));

    let displayOrderCounter = lineItemsToPersist.length + 1;

    // 4. Evaluate promotional coupon if provided
    let appliedCouponCode: string | undefined;
    if (input.couponCode) {
      const promoResult = await this.promotionEngine.evaluatePromotion(input.couponCode, {
        customerId: input.customerId,
        vendorId: input.vendorId || car.vendorId,
        branchId: input.branchId,
        vehicleClass: input.vehicleClass || car.type,
        tripType: input.tripType,
        subtotal,
        durationDays,
        startDate: start,
        endDate: end,
        existingDiscountsCount: discountTotal > 0 ? 1 : 0,
      });

      if (promoResult.isValid && promoResult.effectiveDiscountAmount > 0) {
        appliedCouponCode = promoResult.code;
        discountTotal += promoResult.effectiveDiscountAmount;
        lineItemsToPersist.push({
          type: QuoteLineItemType.COUPON_DISCOUNT,
          name: `Coupon Discount (${promoResult.code})`,
          description: promoResult.description,
          rate: promoResult.effectiveDiscountAmount,
          quantity: 1,
          amount: -promoResult.effectiveDiscountAmount,
          isRefundable: false,
          displayOrder: displayOrderCounter++,
        });
      }
    }

    // 5. Evaluate and append Ancillary / Optional products
    if (input.ancillaries && input.ancillaries.length > 0) {
      const ancillaryResult = await this.ancillaryService.calculateAncillariesTotal(
        input.ancillaries,
        durationDays,
        subtotal,
        input.vendorId || car.vendorId,
      );

      for (const anc of ancillaryResult.items) {
        feesTotal += anc.subtotal;
        taxTotal += anc.taxAmount;
        lineItemsToPersist.push({
          type: QuoteLineItemType.EXTRA_ADDON,
          name: anc.name,
          description: `Addon: ${anc.category} (${anc.pricingModel})`,
          rate: anc.unitPrice,
          quantity: anc.quantity,
          amount: anc.subtotal,
          isRefundable: false,
          displayOrder: displayOrderCounter++,
        });
      }
    }

    // 6. Compute final authoritative total payable
    const totalPayable = Math.max(
      0,
      Math.round((subtotal - discountTotal + feesTotal + taxTotal + depositTotal) * 100) / 100,
    );

    // 7. Calculate cryptographic integrity checksum to detect tampering
    const checksumPayload = `${car.id}:${start.toISOString()}:${end.toISOString()}:${subtotal}:${discountTotal}:${feesTotal}:${taxTotal}:${depositTotal}:${totalPayable}`;
    const integrityChecksum = crypto.createHash('sha256').update(checksumPayload).digest('hex');

    const expiresAt = new Date(Date.now() + MarketplaceQuoteService.QUOTE_LOCK_DURATION_MINUTES * 60 * 1000);

    // 8. Persist locked BookingQuote record
    const createdQuote = await this.prisma.bookingQuote.create({
      data: {
        tenantId: input.vendorId || car.vendorId,
        customerId: input.customerId,
        carId: car.id,
        tripType: input.tripType || TripType.SELF_DRIVE,
        startDate: start,
        endDate: end,
        durationDays,
        durationHours,
        pricingVersion: resolvedPricing.version,
        currency: resolvedPricing.currency,
        subtotal: new Prisma.Decimal(subtotal),
        discountTotal: new Prisma.Decimal(discountTotal),
        feesTotal: new Prisma.Decimal(feesTotal),
        taxTotal: new Prisma.Decimal(taxTotal),
        depositTotal: new Prisma.Decimal(depositTotal),
        totalPayable: new Prisma.Decimal(totalPayable),
        netToVendor: new Prisma.Decimal(netToVendor),
        status: QuoteStatus.ACTIVE,
        expiresAt,
        idempotencyKey: input.idempotencyKey,
        metadata: {
          integrityChecksum,
          vehicleClass: input.vehicleClass || car.type,
          appliedCouponCode,
          appliedRuleIds: resolvedPricing.appliedRuleIds,
          ancillarySelections: (input.ancillaries as any) || [],
          deliveryAddress: input.deliveryAddress,
        } as any,
        lineItems: {
          create: lineItemsToPersist.map((item) => ({
            type: item.type,
            name: item.name,
            description: item.description,
            rate: new Prisma.Decimal(item.rate),
            quantity: new Prisma.Decimal(item.quantity),
            amount: new Prisma.Decimal(item.amount),
            isRefundable: item.isRefundable,
            displayOrder: item.displayOrder,
          })),
        },
      },
      include: {
        lineItems: { orderBy: { displayOrder: 'asc' } },
      },
    });

    return this.mapToSnapshot(createdQuote);
  }

  /**
   * Retrieves and verifies an active quote. If expired, updates its status and throws ConflictException.
   */
  async getVerifiedQuote(quoteId: string): Promise<AuthoritativeQuoteSnapshot> {
    const quote = await this.prisma.bookingQuote.findUnique({
      where: { id: quoteId },
      include: { lineItems: { orderBy: { displayOrder: 'asc' } } },
    });

    if (!quote) {
      throw new NotFoundException(`Quote '${quoteId}' not found.`);
    }

    if (quote.status === QuoteStatus.ACTIVE && quote.expiresAt < new Date()) {
      await this.prisma.bookingQuote.update({
        where: { id: quote.id },
        data: { status: QuoteStatus.EXPIRED },
      });
      throw new ConflictException(
        'The quote has expired (15-minute lock exceeded). Please refresh the quote to proceed with current rates.',
      );
    }

    if (quote.status !== QuoteStatus.ACTIVE) {
      throw new ConflictException(`This quote is no longer active (status: ${quote.status}).`);
    }

    return this.mapToSnapshot(quote);
  }

  /**
   * Refreshes an expired quote, regenerating an authoritative lock with fresh rates.
   */
  async refreshQuote(quoteId: string, customerId?: string): Promise<AuthoritativeQuoteSnapshot> {
    const oldQuote = await this.prisma.bookingQuote.findUnique({
      where: { id: quoteId },
      include: { lineItems: true },
    });

    if (!oldQuote) {
      throw new NotFoundException(`Quote '${quoteId}' not found.`);
    }

    // Mark previous quote as SUPERSEDED
    if (oldQuote.status === QuoteStatus.ACTIVE || oldQuote.status === QuoteStatus.EXPIRED) {
      await this.prisma.bookingQuote.update({
        where: { id: quoteId },
        data: { status: QuoteStatus.SUPERSEDED },
      });
    }

    const meta = (oldQuote.metadata as any) || {};

    return this.createQuote({
      customerId: customerId || oldQuote.customerId || undefined,
      vendorId: oldQuote.tenantId,
      carId: oldQuote.carId,
      vehicleClass: meta.vehicleClass || CarCategory.SEDAN,
      startDate: oldQuote.startDate,
      endDate: oldQuote.endDate,
      tripType: oldQuote.tripType,
      couponCode: meta.appliedCouponCode,
      ancillaries: meta.ancillarySelections,
      deliveryAddress: meta.deliveryAddress,
    });
  }

  private mapToSnapshot(quote: any): AuthoritativeQuoteSnapshot {
    const meta = (quote.metadata as any) || {};
    return {
      quoteId: quote.id,
      tenantId: quote.tenantId,
      customerId: quote.customerId,
      carId: quote.carId,
      vehicleClass: meta.vehicleClass || CarCategory.SEDAN,
      tripType: quote.tripType || TripType.SELF_DRIVE,
      startDate: quote.startDate ? (quote.startDate instanceof Date ? quote.startDate.toISOString() : new Date(quote.startDate).toISOString()) : new Date().toISOString(),
      endDate: quote.endDate ? (quote.endDate instanceof Date ? quote.endDate.toISOString() : new Date(quote.endDate).toISOString()) : new Date().toISOString(),
      durationDays: quote.durationDays || 1,
      durationHours: quote.durationHours || 24,
      pricingVersion: quote.pricingVersion || 'v2.0-enterprise',
      currency: quote.currency || 'INR',
      subtotal: Number(quote.subtotal || 0),
      discountTotal: Number(quote.discountTotal || 0),
      feesTotal: Number(quote.feesTotal || 0),
      taxTotal: Number(quote.taxTotal || 0),
      depositTotal: Number(quote.depositTotal || 0),
      totalPayable: Number(quote.totalPayable || 0),
      netToVendor: Number(quote.netToVendor || 0),
      expiresAt: quote.expiresAt ? (quote.expiresAt instanceof Date ? quote.expiresAt.toISOString() : new Date(quote.expiresAt).toISOString()) : new Date().toISOString(),
      status: quote.status || QuoteStatus.ACTIVE,
      integrityChecksum: meta.integrityChecksum || '',
      lineItems: (quote.lineItems || []).map((li: any) => ({
        type: li.type,
        name: li.name,
        description: li.description,
        rate: Number(li.rate),
        quantity: Number(li.quantity),
        amount: Number(li.amount),
        isRefundable: li.isRefundable,
      })),
      appliedRules: meta.appliedRuleIds || [],
    };
  }
}
