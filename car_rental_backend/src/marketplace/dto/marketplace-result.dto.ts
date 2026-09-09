import { CarCategory, TripType } from '@prisma/client';

export interface MarketplaceVendorSummary {
  id: string;
  name: string;
  rating: number;
  reviewCount: number;
  isVerified: boolean;
  tier: string;
  city: string;
  yearsInOperation: number;
}

export interface MarketplaceBranchSummary {
  id: string;
  name: string;
  address: string;
  locality?: string;
  city: string;
  latitude: number;
  longitude: number;
  operatingHours?: string;
  isAirportHub: boolean;
  distanceKm?: number;
}

export interface MarketplaceExampleVehicle {
  carId: string;
  make: string;
  model: string;
  year: number;
  images: string[];
  transmission: string;
  fuelType: string;
  seatingCapacity: number;
  luggageCapacity: number;
  features: string[];
  isElectric: boolean;
  batteryRangeKm?: number;
}

export interface MarketplacePricingSummary {
  dailyRate: number;
  hourlyRate: number;
  durationDays: number;
  durationHours: number;
  estimatedBaseFare: number;
  estimatedTaxes: number;
  estimatedFees: number;
  estimatedDeposit: number;
  estimatedDiscounts: number;
  estimatedTotal: number;
  currency: string;
  pricingVersion: string;
}

export interface MarketplaceDistancePolicy {
  includedKmPerDay: number | null; // null = unlimited
  extraKmRate: number;
  isUnlimited: boolean;
}

export interface MarketplacePolicies {
  cancellationSummary: string;
  freeCancellationHours: number;
  fuelPolicy: string;
  depositPolicy: string;
  depositAmount: number;
  minDriverAge: number;
}

export interface MarketplaceFulfillmentOptions {
  pickupAtBranch: boolean;
  pickupFee: number;
  deliveryAvailable: boolean;
  deliveryEstimatedFee: number;
  oneWayAvailable: boolean;
  oneWayFee: number;
}

export interface MarketplaceSearchResultItem {
  marketplaceId: string; // vendorId:branchId:vehicleClass:carId
  vehicleClass: CarCategory;
  vehicleClassName: string;
  exampleVehicle: MarketplaceExampleVehicle;
  vendor: MarketplaceVendorSummary;
  branch: MarketplaceBranchSummary;
  pricing: MarketplacePricingSummary;
  distancePolicy: MarketplaceDistancePolicy;
  policies: MarketplacePolicies;
  fulfillment: MarketplaceFulfillmentOptions;
  availability: {
    availableVehiclesCount: number;
    instantConfirmation: boolean;
    confidenceScore: number;
    estimatedReadinessMinutes: number;
  };
  score: {
    compositeScore: number;
    priceScore: number;
    vendorScore: number;
    availabilityScore: number;
    proximityScore: number;
    readinessScore: number;
  };
  badges: string[]; // ['BEST_VALUE', 'TOP_RATED', 'ELECTRIC', 'INSTANT_BOOK', 'POPULAR']
}

export interface FacetCountItem {
  key: string;
  label: string;
  count: number;
}

export interface MarketplaceFacetsDto {
  vehicleClasses: FacetCountItem[];
  transmissions: FacetCountItem[];
  fuelTypes: FacetCountItem[];
  seatingCapacities: FacetCountItem[];
  vendors: FacetCountItem[];
  priceRange: {
    min: number;
    max: number;
  };
  fulfillment: {
    deliveryCount: number;
    instantConfirmationCount: number;
    airportCount: number;
    electricCount: number;
  };
}

export interface MarketplaceSearchResponseDto {
  success: boolean;
  totalResults: number;
  page: number;
  limit: number;
  totalPages: number;
  appliedStrategy: string;
  results: MarketplaceSearchResultItem[];
  facets: MarketplaceFacetsDto;
}
