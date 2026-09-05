import { QuoteLineItemType, QuoteStatus, TripType, DeliveryType } from '@prisma/client';

export interface QuoteLineItemDto {
  id?: string;
  type: QuoteLineItemType;
  name: string;
  description?: string;
  rate: number;
  quantity: number;
  amount: number;
  isRefundable: boolean;
  displayOrder: number;
}

export interface BookingQuoteResponseDto {
  quoteId: string;
  tenantId: string;
  carId: string;
  vehicleName: string;
  registrationNumber: string;
  tripType: TripType;
  startDate: string;
  endDate: string;
  durationDays: number;
  durationHours: number;
  currency: string;
  pricingVersion: string;
  subtotal: number;
  discountTotal: number;
  feesTotal: number;
  taxTotal: number;
  depositTotal: number;
  tripFare: number;
  totalPayable: number;
  netToVendor: number;
  status: QuoteStatus;
  createdAt: string;
  expiresAt: string;
  acceptedAt?: string | null;
  lineItems: QuoteLineItemDto[];
  metadata?: Record<string, any>;
}

export interface PriceSnapshotJson {
  quoteId: string;
  pricingVersion: string;
  currency: string;
  durationDays: number;
  durationHours: number;
  subtotal: number;
  discountTotal: number;
  feesTotal: number;
  taxTotal: number;
  depositTotal: number;
  tripFare: number;
  totalPayable: number;
  netToVendor: number;
  acceptedAt: string;
  lineItems: Array<{
    type: QuoteLineItemType;
    name: string;
    rate: number;
    quantity: number;
    amount: number;
    isRefundable: boolean;
  }>;
  metadata?: Record<string, any>;
}
