import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Logger,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CommissionResolverService } from '../common/commission-resolver.service';
import { FareCalculatorService } from '../common/fare-calculator.service';
import { CouponsService } from '../coupons/coupons.service';
import { DepositRulesService } from '../deposits/deposit-rules.service';
import { LocationsService } from '../locations/locations.service';
import { VehicleAvailabilityService } from '../cars/vehicle-availability.service';
import { CreateQuoteDto } from './dto/create-quote.dto';
import {
  QuoteLineItemDto,
  BookingQuoteResponseDto,
  PriceSnapshotJson,
} from './pricing.types';
import {
  Prisma,
  QuoteLineItemType,
  QuoteStatus,
  TripType,
  Role,
} from '@prisma/client';

export const QUOTE_VALIDITY_MINUTES = 15;

@Injectable()
export class PricingService {
  private readonly logger = new Logger(PricingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly commissionResolver: CommissionResolverService,
    private readonly fareCalculator: FareCalculatorService,
    @Optional() private readonly couponsService?: CouponsService,
    @Optional() private readonly depositRulesService?: DepositRulesService,
    @Optional() private readonly locationsService?: LocationsService,
    @Optional() private readonly availabilityService?: VehicleAvailabilityService,
  ) {}

  /**
   * Generates a canonical, server-authoritative quote with structured line items
   * and persists it with a 15-minute TTL.
   */
  async generateQuote(
    dto: CreateQuoteDto,
    user?: { userId: string; role?: Role | string },
  ): Promise<BookingQuoteResponseDto> {
    const start = new Date(dto.startDate);
    const end = new Date(dto.endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Invalid start or end date format.');
    }

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date.');
    }

    // Allow a 2-minute clock skew buffer for past check
    if (start.getTime() < Date.now() - 120000) {
      throw new BadRequestException('Start date cannot be in the past.');
    }

    // Check idempotency if idempotencyKey is provided
    if (dto.idempotencyKey) {
      const existingQuote = await this.prisma.bookingQuote.findUnique({
        where: { idempotencyKey: dto.idempotencyKey },
        include: {
          lineItems: { orderBy: { displayOrder: 'asc' } },
          car: true,
        },
      });

      if (
        existingQuote &&
        existingQuote.status === QuoteStatus.ACTIVE &&
        existingQuote.expiresAt > new Date()
      ) {
        return this.mapQuoteToResponse(existingQuote);
      }
    }

    // Fetch Car and Vendor details
    const car = await this.prisma.car.findUnique({
      where: { id: dto.carId },
      include: {
        vendor: true,
        mileagePackages: true,
      },
    });

    if (!car) {
      throw new NotFoundException('Car not found.');
    }

    if (!car.isAvailable) {
      throw new ConflictException('This car is marked as unavailable.');
    }

    if (car.vendor?.verificationStatus !== 'VERIFIED') {
      throw new BadRequestException(
        'Cannot book a vehicle from an unverified vendor.',
      );
    }

    if (
      car.availableTripTypes &&
      car.availableTripTypes.length > 0 &&
      !car.availableTripTypes.includes(dto.tripType)
    ) {
      throw new BadRequestException(
        `This car does not support ${dto.tripType} trip type.`,
      );
    }

    // Check Phase 34 availability
    if (this.availabilityService) {
      const avail = await this.availabilityService.checkAvailability(
        dto.carId,
        start,
        end,
        { actorId: user?.userId },
      );
      if (!avail.available) {
        throw new ConflictException(
          avail.reason || 'Vehicle is not available for the requested period.',
        );
      }
    }

    // Calculate duration
    const durationMs = end.getTime() - start.getTime();
    const durationDays = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60 * 24)));
    const durationHours = Math.max(1, Math.ceil(durationMs / (1000 * 60 * 60)));

    const lineItems: QuoteLineItemDto[] = [];
    let orderIndex = 1;

    // 1. Base Rental Line Item
    let baseLineType: QuoteLineItemType = QuoteLineItemType.BASE_RENTAL;
    let baseRateName = 'Daily Rental Rate';
    let baseRateDesc = `${durationDays} day(s) @ ₹${Number(car.pricePerDay).toFixed(2)}/day`;
    let baseUnitPrice = new Prisma.Decimal(car.pricePerDay);
    let baseQuantity = new Prisma.Decimal(durationDays);
    let initialBaseFare = baseUnitPrice.mul(baseQuantity);

    let selectedMileagePackage: any = null;

    if (dto.mileagePackageId) {
      selectedMileagePackage = car.mileagePackages.find(
        (pkg) => pkg.id === dto.mileagePackageId && pkg.isActive,
      );
      if (!selectedMileagePackage) {
        throw new NotFoundException('Selected mileage package not found or inactive.');
      }
      if (selectedMileagePackage.tripType !== dto.tripType) {
        throw new BadRequestException(
          `Mileage package is for ${selectedMileagePackage.tripType} but requested trip is for ${dto.tripType}.`,
        );
      }
      baseLineType = QuoteLineItemType.PACKAGE_TIER;
      baseRateName = `Package: ${selectedMileagePackage.name}`;
      const kmDesc = selectedMileagePackage.includedKmPerDay
        ? `${selectedMileagePackage.includedKmPerDay * durationDays} km included`
        : 'Unlimited km';
      baseRateDesc = `${durationDays} day(s) @ ₹${Number(selectedMileagePackage.basePricePerDay).toFixed(2)}/day (${kmDesc})`;
      baseUnitPrice = new Prisma.Decimal(selectedMileagePackage.basePricePerDay);
      baseQuantity = new Prisma.Decimal(durationDays);
      initialBaseFare = baseUnitPrice.mul(baseQuantity);
    } else if (
      dto.tripType === TripType.LOCAL ||
      dto.tripType === TripType.AIRPORT_TRANSFER
    ) {
      baseLineType = QuoteLineItemType.HOURLY_RENTAL;
      baseRateName = 'Hourly Rental Rate';
      baseRateDesc = `${durationHours} hour(s) @ ₹${Number(car.pricePerHour).toFixed(2)}/hour`;
      baseUnitPrice = new Prisma.Decimal(car.pricePerHour);
      baseQuantity = new Prisma.Decimal(durationHours);
      initialBaseFare = baseUnitPrice.mul(baseQuantity);
    }

    lineItems.push({
      type: baseLineType,
      name: baseRateName,
      description: baseRateDesc,
      rate: baseUnitPrice.toNumber(),
      quantity: baseQuantity.toNumber(),
      amount: initialBaseFare.toDecimalPlaces(2).toNumber(),
      isRefundable: false,
      displayOrder: orderIndex++,
    });

    // 2. Multi-Day Duration Discount
    let durationDiscountPct = 0;
    if (durationDays >= 30 && car.monthlyDiscountPercent && car.monthlyDiscountPercent > 0) {
      durationDiscountPct = car.monthlyDiscountPercent;
    } else if (durationDays >= 7 && car.weeklyDiscountPercent && car.weeklyDiscountPercent > 0) {
      durationDiscountPct = car.weeklyDiscountPercent;
    }

    let durationDiscountAmount = new Prisma.Decimal(0);
    let baseFareAfterDurationDiscount = initialBaseFare;

    if (durationDiscountPct > 0) {
      durationDiscountAmount = initialBaseFare
        .mul(durationDiscountPct / 100)
        .toDecimalPlaces(2);
      baseFareAfterDurationDiscount = initialBaseFare.sub(durationDiscountAmount);

      lineItems.push({
        type: QuoteLineItemType.DURATION_DISCOUNT,
        name: `Duration Discount (${durationDiscountPct}%)`,
        description: `Special rate applied for ${durationDays}+ days rental`,
        rate: durationDiscountAmount.toNumber(),
        quantity: 1,
        amount: -durationDiscountAmount.toNumber(),
        isRefundable: false,
        displayOrder: orderIndex++,
      });
    }

    // 3. Platform Convenience Fee & GST
    const commissionPercent =
      await this.commissionResolver.resolveCommissionPercent(
        car.vendor.city,
        car.type,
        dto.tripType,
      );

    const platformFee = baseFareAfterDurationDiscount
      .mul(new Prisma.Decimal(commissionPercent).div(100))
      .toDecimalPlaces(2);

    lineItems.push({
      type: QuoteLineItemType.PLATFORM_FEE,
      name: 'Platform Service Fee',
      description: `Platform technology & roadside assistance fee (${Number(commissionPercent)}%)`,
      rate: platformFee.toNumber(),
      quantity: 1,
      amount: platformFee.toNumber(),
      isRefundable: false,
      displayOrder: orderIndex++,
    });

    const gstAmount = platformFee.mul(0.18).toDecimalPlaces(2);
    lineItems.push({
      type: QuoteLineItemType.GST,
      name: 'GST (18% on Platform Fee)',
      description: 'Government Goods and Services Tax on platform services',
      rate: gstAmount.toNumber(),
      quantity: 1,
      amount: gstAmount.toNumber(),
      isRefundable: false,
      displayOrder: orderIndex++,
    });

    // 4. Fulfillment & Location Charges
    let deliveryFee = new Prisma.Decimal(0);
    let pickupFee = new Prisma.Decimal(0);
    let returnFee = new Prisma.Decimal(0);
    let oneWayFee = new Prisma.Decimal(0);

    if (
      this.locationsService &&
      (dto.pickupHubId ||
        dto.returnHubId ||
        dto.deliveryLatitude !== undefined ||
        dto.deliveryAddress)
    ) {
      try {
        const locQuote = await this.locationsService.calculateDeliveryQuote({
          vendorId: car.vendorId,
          customerLatitude: dto.deliveryLatitude,
          customerLongitude: dto.deliveryLongitude,
          deliveryAddress: dto.deliveryAddress,
          pickupLocationId: dto.pickupHubId,
          returnLocationId: dto.returnHubId,
          carId: dto.carId,
          startDate: dto.startDate,
          endDate: dto.endDate,
          pickupDate: dto.startDate,
          returnDate: dto.endDate,
        });

        if (!locQuote.isAvailable && dto.deliveryType && dto.deliveryType !== 'NONE') {
          throw new BadRequestException(
            locQuote.reason || 'Requested fulfillment option is unavailable.',
          );
        }

        deliveryFee = new Prisma.Decimal(locQuote.deliveryFee || 0).toDecimalPlaces(2);
        pickupFee = new Prisma.Decimal(locQuote.pickupFee || 0).toDecimalPlaces(2);
        returnFee = new Prisma.Decimal(locQuote.returnFee || 0).toDecimalPlaces(2);
        oneWayFee = new Prisma.Decimal(locQuote.oneWaySurcharge || 0).toDecimalPlaces(2);
      } catch (err: any) {
        if (
          err instanceof BadRequestException ||
          err instanceof ConflictException
        ) {
          throw err;
        }
        this.logger.warn(`Location quote calculation fallback: ${err.message}`);
      }
    }

    if (deliveryFee.gt(0)) {
      lineItems.push({
        type: QuoteLineItemType.DELIVERY_FEE,
        name: 'Doorstep Delivery Fee',
        description: 'Vehicle delivery to specified customer address',
        rate: deliveryFee.toNumber(),
        quantity: 1,
        amount: deliveryFee.toNumber(),
        isRefundable: false,
        displayOrder: orderIndex++,
      });
    }

    if (pickupFee.gt(0)) {
      lineItems.push({
        type: QuoteLineItemType.PICKUP_FEE,
        name: 'Pickup Hub Fee',
        description: 'Operational processing at pickup branch',
        rate: pickupFee.toNumber(),
        quantity: 1,
        amount: pickupFee.toNumber(),
        isRefundable: false,
        displayOrder: orderIndex++,
      });
    }

    if (returnFee.gt(0)) {
      lineItems.push({
        type: QuoteLineItemType.RETURN_FEE,
        name: 'Return Hub Fee',
        description: 'Operational processing at return branch',
        rate: returnFee.toNumber(),
        quantity: 1,
        amount: returnFee.toNumber(),
        isRefundable: false,
        displayOrder: orderIndex++,
      });
    }

    if (oneWayFee.gt(0)) {
      lineItems.push({
        type: QuoteLineItemType.ONE_WAY_SURCHARGE,
        name: 'One-Way Relocation Surcharge',
        description: 'Cross-branch fleet repositioning fee',
        rate: oneWayFee.toNumber(),
        quantity: 1,
        amount: oneWayFee.toNumber(),
        isRefundable: false,
        displayOrder: orderIndex++,
      });
    }

    // 5. Optional Protection Package
    let protectionFee = new Prisma.Decimal(0);
    let protectionPackageName: string | null = null;
    let protectionDeductible: number | null = null;

    if (dto.protectionPackageId) {
      const pkg = await this.prisma.protectionPackage.findUnique({
        where: { id: dto.protectionPackageId },
      });
      if (pkg && pkg.isActive) {
        if (!pkg.city || pkg.city.toLowerCase() === car.vendor.city.toLowerCase()) {
          protectionFee = pkg.dailyRate.mul(durationDays).toDecimalPlaces(2);
          protectionPackageName = pkg.name;
          protectionDeductible = Number(pkg.deductibleAmount);

          lineItems.push({
            type: QuoteLineItemType.PROTECTION_FEE,
            name: `Protection Plan (${pkg.name})`,
            description: `Zero-deductible coverage (Deductible: ₹${protectionDeductible})`,
            rate: pkg.dailyRate.toNumber(),
            quantity: durationDays,
            amount: protectionFee.toNumber(),
            isRefundable: false,
            displayOrder: orderIndex++,
          });
        }
      }
    }

    // 6. Coupon Discount
    let couponDiscount = new Prisma.Decimal(0);
    let validatedCouponCode: string | null = null;

    if (dto.couponCode && this.couponsService) {
      const subtotalForCoupon = baseFareAfterDurationDiscount
        .add(platformFee)
        .add(gstAmount);

      const valCoupon = await this.couponsService.validateCoupon(
        user?.userId || 'anonymous-quote',
        {
          code: dto.couponCode,
          carId: dto.carId,
          subtotal: subtotalForCoupon.toNumber(),
          city: car.vendor.city,
          tripType: dto.tripType,
          carCategory: car.type,
        },
      );

      couponDiscount = new Prisma.Decimal(valCoupon.discountAmount || 0).toDecimalPlaces(2);
      validatedCouponCode = valCoupon.code;

      if (couponDiscount.gt(0)) {
        lineItems.push({
          type: QuoteLineItemType.COUPON_DISCOUNT,
          name: `Coupon Discount (${valCoupon.code})`,
          description: 'Promotional discount voucher',
          rate: couponDiscount.toNumber(),
          quantity: 1,
          amount: -couponDiscount.toNumber(),
          isRefundable: false,
          displayOrder: orderIndex++,
        });
      }
    }

    // 7. Security Deposit
    let depositAmount = new Prisma.Decimal(5000);
    if (this.depositRulesService) {
      const resolvedDeposit = await this.depositRulesService.getDepositAmount(
        car.type,
        car.vendor?.city,
      );
      depositAmount = new Prisma.Decimal(resolvedDeposit).toDecimalPlaces(2);
    }

    lineItems.push({
      type: QuoteLineItemType.SECURITY_DEPOSIT,
      name: 'Refundable Security Deposit',
      description: 'Refunded automatically within 24 hours after safe return',
      rate: depositAmount.toNumber(),
      quantity: 1,
      amount: depositAmount.toNumber(),
      isRefundable: true,
      displayOrder: 99,
    });

    // 8. Compute Authoritative Totals
    const subtotal = initialBaseFare.toDecimalPlaces(2);
    const discountTotal = durationDiscountAmount.add(couponDiscount).toDecimalPlaces(2);
    const fulfillmentTotal = deliveryFee.add(pickupFee).add(returnFee).add(oneWayFee).toDecimalPlaces(2);
    const feesTotal = platformFee.add(fulfillmentTotal).add(protectionFee).toDecimalPlaces(2);
    const taxTotal = gstAmount.toDecimalPlaces(2);
    const depositTotal = depositAmount.toDecimalPlaces(2);

    const tripFare = baseFareAfterDurationDiscount
      .add(platformFee)
      .add(gstAmount)
      .add(fulfillmentTotal)
      .add(protectionFee)
      .sub(couponDiscount)
      .toDecimalPlaces(2);

    const totalPayable = tripFare.add(depositTotal).toDecimalPlaces(2);
    const netToVendor = baseFareAfterDurationDiscount.add(fulfillmentTotal).toDecimalPlaces(2);

    const expiresAt = new Date(Date.now() + QUOTE_VALIDITY_MINUTES * 60 * 1000);

    // 9. Persist Quote and Line Items
    const quote = await this.prisma.bookingQuote.create({
      data: {
        tenantId: car.vendorId,
        customerId: user?.userId,
        carId: dto.carId,
        tripType: dto.tripType,
        startDate: start,
        endDate: end,
        durationDays,
        durationHours,
        pricingVersion: 'v1.0',
        currency: 'INR',
        subtotal,
        discountTotal,
        feesTotal,
        taxTotal,
        depositTotal,
        totalPayable,
        netToVendor,
        status: QuoteStatus.ACTIVE,
        expiresAt,
        idempotencyKey: dto.idempotencyKey,
        metadata: {
          mileagePackageId: selectedMileagePackage?.id,
          mileagePackageName: selectedMileagePackage?.name,
          couponCode: validatedCouponCode,
          protectionPackageName,
          protectionDeductible,
          deliveryAddress: dto.deliveryAddress,
          pickupHubId: dto.pickupHubId,
          returnHubId: dto.returnHubId,
        },
        lineItems: {
          create: lineItems.map((item) => ({
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
        car: true,
      },
    });

    return this.mapQuoteToResponse(quote);
  }

  /**
   * Retrieves an existing quote by ID, ensuring tenant isolation and updating expiry if needed.
   */
  async getQuoteById(
    quoteId: string,
    user?: { userId: string; role?: Role | string },
  ): Promise<BookingQuoteResponseDto> {
    const quote = await this.prisma.bookingQuote.findUnique({
      where: { id: quoteId },
      include: {
        lineItems: { orderBy: { displayOrder: 'asc' } },
        car: true,
      },
    });

    if (!quote) {
      throw new NotFoundException('Quote not found.');
    }

    // Tenant isolation: if vendor, must match tenantId
    if (user?.role === Role.VENDOR && quote.tenantId !== user.userId) {
      const vendor = await this.prisma.vendor.findUnique({ where: { userId: user.userId } });
      if (!vendor || vendor.id !== quote.tenantId) {
        throw new ForbiddenException('Access denied to quote belonging to another fleet.');
      }
    }

    // Customer isolation: if customer, must match customerId if quote is bound
    if (
      user?.role === Role.CUSTOMER &&
      quote.customerId &&
      quote.customerId !== user.userId
    ) {
      throw new ForbiddenException('Access denied to quote belonging to another user.');
    }

    // Check if expired
    if (quote.status === QuoteStatus.ACTIVE && quote.expiresAt < new Date()) {
      const updated = await this.prisma.bookingQuote.update({
        where: { id: quote.id },
        data: { status: QuoteStatus.EXPIRED },
        include: {
          lineItems: { orderBy: { displayOrder: 'asc' } },
          car: true,
        },
      });
      return this.mapQuoteToResponse(updated);
    }

    return this.mapQuoteToResponse(quote);
  }

  /**
   * Refreshes an expired or stale quote, regenerating current prices.
   */
  async refreshQuote(
    quoteId: string,
    user?: { userId: string; role?: Role | string },
  ): Promise<BookingQuoteResponseDto> {
    const oldQuote = await this.prisma.bookingQuote.findUnique({
      where: { id: quoteId },
      include: { lineItems: true },
    });

    if (!oldQuote) {
      throw new NotFoundException('Quote not found.');
    }

    // Mark previous quote as SUPERSEDED if still ACTIVE
    if (oldQuote.status === QuoteStatus.ACTIVE) {
      await this.prisma.bookingQuote.update({
        where: { id: quoteId },
        data: { status: QuoteStatus.SUPERSEDED },
      });
    }

    const meta = (oldQuote.metadata as any) || {};

    return this.generateQuote(
      {
        carId: oldQuote.carId,
        startDate: oldQuote.startDate.toISOString(),
        endDate: oldQuote.endDate.toISOString(),
        tripType: oldQuote.tripType,
        pickupHubId: meta.pickupHubId,
        returnHubId: meta.returnHubId,
        couponCode: meta.couponCode,
        mileagePackageId: meta.mileagePackageId,
        deliveryAddress: meta.deliveryAddress,
      },
      user,
    );
  }

  /**
   * Verifies and atomically accepts an active quote during booking creation.
   */
  async verifyAndAcceptQuote(
    tx: any,
    quoteId: string,
    customerId: string,
    context: {
      carId: string;
      startDate: Date | string;
      endDate: Date | string;
      tripType: TripType;
    },
  ): Promise<{
    quote: any;
    priceSnapshot: PriceSnapshotJson;
  }> {
    const quote = await tx.bookingQuote.findUnique({
      where: { id: quoteId },
      include: {
        lineItems: { orderBy: { displayOrder: 'asc' } },
        car: true,
      },
    });

    if (!quote) {
      throw new NotFoundException('Specified quoteId not found.');
    }

    if (quote.status === QuoteStatus.EXPIRED || quote.expiresAt < new Date()) {
      throw new ConflictException(
        'The accepted quote has expired. Please refresh the quote before booking.',
      );
    }

    if (quote.status !== QuoteStatus.ACTIVE) {
      throw new ConflictException(
        `This quote is no longer active (current status: ${quote.status}).`,
      );
    }

    if (quote.carId !== context.carId) {
      throw new BadRequestException('Quote does not match the selected car.');
    }

    if (quote.tripType !== context.tripType) {
      throw new BadRequestException('Quote does not match the selected trip type.');
    }

    const start = new Date(context.startDate);
    const end = new Date(context.endDate);

    // Verify dates match quote within a 2-minute margin
    const startDiff = Math.abs(start.getTime() - quote.startDate.getTime());
    const endDiff = Math.abs(end.getTime() - quote.endDate.getTime());
    if (startDiff > 120000 || endDiff > 120000) {
      throw new ConflictException(
        'Requested booking dates do not match the accepted quote.',
      );
    }

    // Atomically transition status to ACCEPTED
    const acceptedQuote = await tx.bookingQuote.update({
      where: { id: quoteId },
      data: {
        status: QuoteStatus.ACCEPTED,
        acceptedAt: new Date(),
        customerId,
      },
      include: {
        lineItems: { orderBy: { displayOrder: 'asc' } },
        car: true,
      },
    });

    const tripFare = acceptedQuote.subtotal
      .sub(acceptedQuote.discountTotal)
      .add(acceptedQuote.feesTotal)
      .add(acceptedQuote.taxTotal);

    const priceSnapshot: PriceSnapshotJson = {
      quoteId: acceptedQuote.id,
      pricingVersion: acceptedQuote.pricingVersion,
      currency: acceptedQuote.currency,
      durationDays: acceptedQuote.durationDays,
      durationHours: acceptedQuote.durationHours,
      subtotal: Number(acceptedQuote.subtotal),
      discountTotal: Number(acceptedQuote.discountTotal),
      feesTotal: Number(acceptedQuote.feesTotal),
      taxTotal: Number(acceptedQuote.taxTotal),
      depositTotal: Number(acceptedQuote.depositTotal),
      tripFare: Number(tripFare),
      totalPayable: Number(acceptedQuote.totalPayable),
      netToVendor: Number(acceptedQuote.netToVendor),
      acceptedAt: new Date().toISOString(),
      lineItems: acceptedQuote.lineItems.map((li: any) => ({
        type: li.type,
        name: li.name,
        rate: Number(li.rate),
        quantity: Number(li.quantity),
        amount: Number(li.amount),
        isRefundable: li.isRefundable,
      })),
      metadata: acceptedQuote.metadata as any,
    };

    return {
      quote: acceptedQuote,
      priceSnapshot,
    };
  }

  private mapQuoteToResponse(quote: any): BookingQuoteResponseDto {
    const tripFare = quote.subtotal
      .sub(quote.discountTotal)
      .add(quote.feesTotal)
      .add(quote.taxTotal);

    return {
      quoteId: quote.id,
      tenantId: quote.tenantId,
      carId: quote.carId,
      vehicleName: quote.car ? `${quote.car.make} ${quote.car.model}` : 'Vehicle',
      registrationNumber: quote.car?.registrationNumber || '',
      tripType: quote.tripType,
      startDate: quote.startDate.toISOString(),
      endDate: quote.endDate.toISOString(),
      durationDays: quote.durationDays,
      durationHours: quote.durationHours,
      currency: quote.currency,
      pricingVersion: quote.pricingVersion,
      subtotal: Number(quote.subtotal),
      discountTotal: Number(quote.discountTotal),
      feesTotal: Number(quote.feesTotal),
      taxTotal: Number(quote.taxTotal),
      depositTotal: Number(quote.depositTotal),
      tripFare: Number(tripFare),
      totalPayable: Number(quote.totalPayable),
      netToVendor: Number(quote.netToVendor),
      status: quote.status,
      createdAt: quote.createdAt.toISOString(),
      expiresAt: quote.expiresAt.toISOString(),
      acceptedAt: quote.acceptedAt?.toISOString() || null,
      lineItems: (quote.lineItems || []).map((li: any) => ({
        id: li.id,
        type: li.type,
        name: li.name,
        description: li.description || undefined,
        rate: Number(li.rate),
        quantity: Number(li.quantity),
        amount: Number(li.amount),
        isRefundable: li.isRefundable,
        displayOrder: li.displayOrder,
      })),
      metadata: quote.metadata as any,
    };
  }
}
