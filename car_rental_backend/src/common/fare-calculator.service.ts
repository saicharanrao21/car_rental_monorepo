import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

@Injectable()
export class FareCalculatorService {
  calculateFare(
    distanceKm: number | string | Prisma.Decimal,
    basePackagePrice: number | string | Prisma.Decimal,
    pricePerKm: number | string | Prisma.Decimal,
    commissionPercent: number | string | Prisma.Decimal,
    durationDays: number = 1,
    weeklyDiscountPercent: number | string | Prisma.Decimal = 0,
    monthlyDiscountPercent: number | string | Prisma.Decimal = 0,
  ) {
    const dKm = new Prisma.Decimal(distanceKm);
    const basePkg = new Prisma.Decimal(basePackagePrice);
    const pPerKm = new Prisma.Decimal(pricePerKm);

    // commissionPercent is stored as e.g. 10.00 (percentage), convert to decimal fraction
    const commPct = new Prisma.Decimal(commissionPercent).div(100);

    // Initial baseFare = (distanceKm * pricePerKm) + basePackagePrice
    const initialBaseFare = dKm.mul(pPerKm).add(basePkg);

    // Multi-day discount determination
    let discountPct = new Prisma.Decimal(0);
    if (durationDays >= 30 && Number(monthlyDiscountPercent) > 0) {
      discountPct = new Prisma.Decimal(monthlyDiscountPercent);
    } else if (durationDays >= 7 && Number(weeklyDiscountPercent) > 0) {
      discountPct = new Prisma.Decimal(weeklyDiscountPercent);
    }

    let discountAmount = new Prisma.Decimal(0);
    let baseFare = initialBaseFare;

    if (discountPct.gt(0)) {
      discountAmount = initialBaseFare.mul(discountPct.div(100));
      baseFare = initialBaseFare.sub(discountAmount);
    }

    // platformFee = baseFare * commissionPercent
    const platformFee = baseFare.mul(commPct);

    // gst = platformFee * 0.18 (GST applies on platformFee)
    const gst = platformFee.mul(0.18);

    // total = baseFare + platformFee + gst
    const total = baseFare.add(platformFee).add(gst);

    // netToVendor = baseFare (vendor gets the base fare, the platform takes platformFee and pays gst)
    const netToVendor = baseFare;

    return {
      baseFare: baseFare.toDecimalPlaces(2),
      originalBaseFare: initialBaseFare.toDecimalPlaces(2),
      discountAmount: discountAmount.toDecimalPlaces(2),
      discountApplied: {
        percentage: discountPct.toNumber(),
        amount: discountAmount.toDecimalPlaces(2),
      },
      platformFee: platformFee.toDecimalPlaces(2),
      gst: gst.toDecimalPlaces(2),
      total: total.toDecimalPlaces(2),
      netToVendor: netToVendor.toDecimalPlaces(2),
    };
  }
}
