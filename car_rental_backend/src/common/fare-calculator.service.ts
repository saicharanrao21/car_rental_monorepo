import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

@Injectable()
export class FareCalculatorService {
  calculateFare(
    distanceKm: number | string | Prisma.Decimal,
    basePackagePrice: number | string | Prisma.Decimal,
    pricePerKm: number | string | Prisma.Decimal,
    commissionPercent: number | string | Prisma.Decimal,
  ) {
    const dKm = new Prisma.Decimal(distanceKm);
    const basePkg = new Prisma.Decimal(basePackagePrice);
    const pPerKm = new Prisma.Decimal(pricePerKm);
    
    // commissionPercent is stored as e.g. 10.00 (percentage), convert to decimal fraction
    const commPct = new Prisma.Decimal(commissionPercent).div(100);

    // baseFare = (distanceKm * pricePerKm) + basePackagePrice
    const baseFare = dKm.mul(pPerKm).add(basePkg);

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
      platformFee: platformFee.toDecimalPlaces(2),
      gst: gst.toDecimalPlaces(2),
      total: total.toDecimalPlaces(2),
      netToVendor: netToVendor.toDecimalPlaces(2),
    };
  }
}
