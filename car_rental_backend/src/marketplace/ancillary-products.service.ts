import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory } from '@prisma/client';

export interface AncillarySelectionInput {
  code: string;
  quantity?: number;
}

export interface CalculatedAncillaryItem {
  id: string;
  code: string;
  name: string;
  category: string;
  pricingModel: string;
  unitPrice: number;
  quantity: number;
  taxRate: number;
  taxAmount: number;
  subtotal: number;
  totalAmount: number;
}

export interface AncillariesCalculationResult {
  items: CalculatedAncillaryItem[];
  ancillariesSubtotal: number;
  ancillariesTaxTotal: number;
  ancillariesTotal: number;
}

@Injectable()
export class AncillaryProductsService {
  private readonly logger = new Logger(AncillaryProductsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Discovers all active optional products eligible for a vendor, branch, and vehicle class.
   */
  async getEligibleAncillaries(params: {
    vendorId?: string;
    branchId?: string;
    vehicleClass?: CarCategory;
  }): Promise<any[]> {
    const products = await this.prisma.ancillaryProduct.findMany({
      where: {
        isActive: true,
        OR: [
          { vendorId: null }, // Platform default
          { vendorId: params.vendorId },
        ],
        AND: [
          {
            OR: [
              { branchId: null },
              { branchId: params.branchId },
            ],
          },
          {
            OR: [
              { vehicleClass: null },
              { vehicleClass: params.vehicleClass },
            ],
          },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });

    return products;
  }

  /**
   * Computes dynamic line-item amounts for selected ancillary products.
   */
  async calculateAncillariesTotal(
    selections: AncillarySelectionInput[],
    rentalDurationDays: number,
    baseFare: number = 0,
    vendorId?: string,
  ): Promise<AncillariesCalculationResult> {
    if (!selections || selections.length === 0) {
      return {
        items: [],
        ancillariesSubtotal: 0,
        ancillariesTaxTotal: 0,
        ancillariesTotal: 0,
      };
    }

    const durationDays = Math.max(1, rentalDurationDays);
    const calculatedItems: CalculatedAncillaryItem[] = [];

    for (const sel of selections) {
      const code = sel.code.trim().toUpperCase();
      const product = await this.prisma.ancillaryProduct.findFirst({
        where: {
          code,
          isActive: true,
          OR: [{ vendorId: null }, { vendorId: vendorId || undefined }],
        },
      });

      if (!product) {
        this.logger.warn(`Ancillary product '${code}' requested but not found or inactive`);
        continue;
      }

      const qty = Math.max(1, Math.min(product.maxQuantity || 5, sel.quantity || 1));
      const unitPrice = Number(product.basePrice);
      const taxRate = Number(product.taxRate || 0.18);

      let itemSubtotal = 0;
      switch (product.pricingModel) {
        case 'PER_DAY':
          itemSubtotal = unitPrice * durationDays * qty;
          break;
        case 'PERCENTAGE':
          itemSubtotal = (baseFare * (unitPrice / 100)) * qty;
          break;
        case 'FLAT':
        default:
          itemSubtotal = unitPrice * qty;
          break;
      }

      const taxAmount = itemSubtotal * taxRate;
      const totalAmount = itemSubtotal + taxAmount;

      calculatedItems.push({
        id: product.id,
        code: product.code,
        name: product.name,
        category: product.category,
        pricingModel: product.pricingModel,
        unitPrice,
        quantity: qty,
        taxRate,
        taxAmount: Math.round(taxAmount * 100) / 100,
        subtotal: Math.round(itemSubtotal * 100) / 100,
        totalAmount: Math.round(totalAmount * 100) / 100,
      });
    }

    const ancillariesSubtotal = calculatedItems.reduce((sum, item) => sum + item.subtotal, 0);
    const ancillariesTaxTotal = calculatedItems.reduce((sum, item) => sum + item.taxAmount, 0);
    const ancillariesTotal = calculatedItems.reduce((sum, item) => sum + item.totalAmount, 0);

    return {
      items: calculatedItems,
      ancillariesSubtotal: Math.round(ancillariesSubtotal * 100) / 100,
      ancillariesTaxTotal: Math.round(ancillariesTaxTotal * 100) / 100,
      ancillariesTotal: Math.round(ancillariesTotal * 100) / 100,
    };
  }

  /**
   * Seeds standard platform default ancillary products if empty.
   */
  async ensureDefaultAncillaries(): Promise<void> {
    const defaultCatalog = [
      {
        code: 'ADDITIONAL_DRIVER',
        name: 'Additional Authorised Driver',
        description: 'Covers an additional licensed driver for the entire rental duration',
        category: 'DRIVER',
        pricingModel: 'PER_DAY',
        basePrice: 250,
        taxRate: 0.18,
        maxQuantity: 2,
      },
      {
        code: 'CHILD_SAFETY_SEAT',
        name: 'Infant / Child Safety Seat',
        description: 'Certified ISOFIX infant safety seat sanitized prior to handover',
        category: 'CHILD_SEAT',
        pricingModel: 'PER_DAY',
        basePrice: 200,
        taxRate: 0.18,
        maxQuantity: 2,
      },
      {
        code: 'GPS_NAVIGATION',
        name: 'Dedicated GPS Navigator',
        description: 'Offline GPS unit with live satellite routing and preloaded maps',
        category: 'GPS',
        pricingModel: 'FLAT',
        basePrice: 500,
        taxRate: 0.18,
        maxQuantity: 1,
      },
      {
        code: 'ROADSIDE_ASSISTANCE',
        name: '24/7 Premium Roadside Assistance',
        description: 'Priority towing, battery jumpstart, tyre puncture service & emergency fuel dispatch',
        category: 'ROADSIDE_ASSISTANCE',
        pricingModel: 'FLAT',
        basePrice: 499,
        taxRate: 0.18,
        maxQuantity: 1,
      },
      {
        code: 'ZERO_DEP_PROTECTION',
        name: 'Zero-Deductible Damage Waiver',
        description: 'Reduces your financial liability for accidental body damages to ₹0',
        category: 'PROTECTION',
        pricingModel: 'PER_DAY',
        basePrice: 450,
        taxRate: 0.18,
        maxQuantity: 1,
      },
      {
        code: 'EV_FAST_CHARGING_PASS',
        name: 'Unlimited High-Speed EV Charging Pass',
        description: 'Access to partner charging stations nationwide with zero per-kWh charge',
        category: 'EV_PACKAGE',
        pricingModel: 'FLAT',
        basePrice: 899,
        taxRate: 0.18,
        maxQuantity: 1,
      },
      {
        code: 'DOORSTEP_DELIVERY',
        name: 'Doorstep Vehicle Delivery & Handover',
        description: 'Direct delivery of vehicle to your home or office address',
        category: 'DELIVERY',
        pricingModel: 'FLAT',
        basePrice: 350,
        taxRate: 0.18,
        maxQuantity: 1,
      },
      {
        code: 'POST_TRIP_CLEANING',
        name: 'Post-Trip Express Cleaning Waiver',
        description: 'Waiver for normal post-trip dirt, sand, and dust without cleaning penalty',
        category: 'CLEANING',
        pricingModel: 'FLAT',
        basePrice: 300,
        taxRate: 0.18,
        maxQuantity: 1,
      },
    ];

    for (const item of defaultCatalog) {
      await this.prisma.ancillaryProduct.upsert({
        where: { code: item.code },
        update: {},
        create: {
          code: item.code,
          name: item.name,
          description: item.description,
          category: item.category,
          pricingModel: item.pricingModel,
          basePrice: item.basePrice,
          taxRate: item.taxRate,
          maxQuantity: item.maxQuantity,
          isActive: true,
        },
      });
    }
  }
}
