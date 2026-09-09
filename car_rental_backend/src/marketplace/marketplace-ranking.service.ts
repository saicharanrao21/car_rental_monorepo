import { Injectable, Logger } from '@nestjs/common';
import { MarketplaceSearchResultItem } from './dto/marketplace-result.dto';
import { MarketplaceRankingStrategyType } from './dto/marketplace-query.dto';

export interface RankingWeights {
  price: number;
  availability: number;
  vendorReliability: number;
  proximity: number;
  vehicleReadiness: number;
  inventoryHealth: number;
}

export interface RankingStrategy {
  readonly name: string;
  readonly weights: RankingWeights;
  scoreCandidate(candidate: MarketplaceSearchResultItem, context: RankingContext): number;
}

export interface RankingContext {
  minPriceInPool: number;
  maxPriceInPool: number;
  customerLocation?: { latitude: number; longitude: number };
}

export class BalancedRankingStrategy implements RankingStrategy {
  readonly name = 'BALANCED';
  readonly weights: RankingWeights = {
    price: 0.25,
    availability: 0.20,
    vendorReliability: 0.20,
    proximity: 0.15,
    vehicleReadiness: 0.10,
    inventoryHealth: 0.10,
  };

  scoreCandidate(candidate: MarketplaceSearchResultItem, ctx: RankingContext): number {
    return computeWeightedScore(candidate, this.weights, ctx);
  }
}

export class PriceFirstRankingStrategy implements RankingStrategy {
  readonly name = 'PRICE_LOW_HIGH';
  readonly weights: RankingWeights = {
    price: 0.55,
    availability: 0.15,
    vendorReliability: 0.15,
    proximity: 0.05,
    vehicleReadiness: 0.05,
    inventoryHealth: 0.05,
  };

  scoreCandidate(candidate: MarketplaceSearchResultItem, ctx: RankingContext): number {
    return computeWeightedScore(candidate, this.weights, ctx);
  }
}

export class VendorReliabilityRankingStrategy implements RankingStrategy {
  readonly name = 'VENDOR_RELIABILITY';
  readonly weights: RankingWeights = {
    price: 0.15,
    availability: 0.15,
    vendorReliability: 0.45,
    proximity: 0.10,
    vehicleReadiness: 0.10,
    inventoryHealth: 0.05,
  };

  scoreCandidate(candidate: MarketplaceSearchResultItem, ctx: RankingContext): number {
    return computeWeightedScore(candidate, this.weights, ctx);
  }
}

export class ProximityRankingStrategy implements RankingStrategy {
  readonly name = 'PROXIMITY';
  readonly weights: RankingWeights = {
    price: 0.15,
    availability: 0.15,
    vendorReliability: 0.15,
    proximity: 0.45,
    vehicleReadiness: 0.05,
    inventoryHealth: 0.05,
  };

  scoreCandidate(candidate: MarketplaceSearchResultItem, ctx: RankingContext): number {
    return computeWeightedScore(candidate, this.weights, ctx);
  }
}

function computeWeightedScore(
  candidate: MarketplaceSearchResultItem,
  weights: RankingWeights,
  ctx: RankingContext,
): number {
  // 1. Price Score: normalized inverted price (cheaper = closer to 1.0)
  const priceRange = Math.max(1, ctx.maxPriceInPool - ctx.minPriceInPool);
  const normalizedPrice = Math.max(0, Math.min(1, (candidate.pricing.estimatedTotal - ctx.minPriceInPool) / priceRange));
  const priceScore = 1.0 - normalizedPrice;

  // 2. Availability Confidence Score
  const availableCount = candidate.availability.availableVehiclesCount;
  const availabilityScore = Math.min(1.0, availableCount / 5);

  // 3. Vendor Reliability Score
  const vendorRating = Math.max(0, Math.min(5, candidate.vendor.rating));
  const ratingScore = vendorRating / 5.0;
  const verifiedBonus = candidate.vendor.isVerified ? 0.1 : 0.0;
  const vendorScore = Math.min(1.0, ratingScore * 0.9 + verifiedBonus);

  // 4. Proximity Score (if distance known, invert; closer is higher)
  let proximityScore = 0.5;
  if (candidate.branch.distanceKm !== undefined && candidate.branch.distanceKm >= 0) {
    proximityScore = Math.max(0.1, Math.min(1.0, 1.0 - candidate.branch.distanceKm / 50));
  } else if (candidate.fulfillment.deliveryAvailable) {
    proximityScore = 0.8;
  }

  // 5. Vehicle Readiness Score
  const currentYear = new Date().getFullYear();
  const age = Math.max(0, currentYear - candidate.exampleVehicle.year);
  const ageScore = Math.max(0.2, 1.0 - age * 0.1);
  const instantBonus = candidate.availability.instantConfirmation ? 0.15 : 0.0;
  const readinessScore = Math.min(1.0, ageScore * 0.85 + instantBonus);

  // 6. Inventory Health Score
  const inventoryHealth = candidate.availability.confidenceScore || 0.8;

  // Store individual component scores on candidate
  candidate.score.priceScore = Math.round(priceScore * 100) / 100;
  candidate.score.vendorScore = Math.round(vendorScore * 100) / 100;
  candidate.score.availabilityScore = Math.round(availabilityScore * 100) / 100;
  candidate.score.proximityScore = Math.round(proximityScore * 100) / 100;
  candidate.score.readinessScore = Math.round(readinessScore * 100) / 100;

  // Compute final weighted composite score (0 to 100)
  const composite = (
    priceScore * weights.price +
    availabilityScore * weights.availability +
    vendorScore * weights.vendorReliability +
    proximityScore * weights.proximity +
    readinessScore * weights.vehicleReadiness +
    inventoryHealth * weights.inventoryHealth
  ) * 100;

  candidate.score.compositeScore = Math.round(composite * 10) / 10;
  return candidate.score.compositeScore;
}

@Injectable()
export class MarketplaceRankingService {
  private readonly logger = new Logger(MarketplaceRankingService.name);
  private readonly strategies: Map<string, RankingStrategy> = new Map();

  constructor() {
    this.registerStrategy(new BalancedRankingStrategy());
    this.registerStrategy(new PriceFirstRankingStrategy());
    this.registerStrategy(new VendorReliabilityRankingStrategy());
    this.registerStrategy(new ProximityRankingStrategy());
  }

  registerStrategy(strategy: RankingStrategy): void {
    this.strategies.set(strategy.name.toUpperCase(), strategy);
  }

  getStrategy(name: string = 'BALANCED'): RankingStrategy {
    return this.strategies.get(name.toUpperCase()) || this.strategies.get('BALANCED')!;
  }

  /**
   * Ranks candidates deterministically using the designated ranking strategy.
   */
  rankCandidates(
    candidates: MarketplaceSearchResultItem[],
    strategyType: MarketplaceRankingStrategyType = MarketplaceRankingStrategyType.BALANCED,
    customerLocation?: { latitude: number; longitude: number },
  ): MarketplaceSearchResultItem[] {
    if (!candidates || candidates.length === 0) {
      return [];
    }

    const prices = candidates.map((c) => c.pricing.estimatedTotal);
    const minPriceInPool = Math.min(...prices);
    const maxPriceInPool = Math.max(...prices);

    const context: RankingContext = {
      minPriceInPool,
      maxPriceInPool,
      customerLocation,
    };

    const strategy = this.getStrategy(strategyType);

    // Score all candidates
    for (const candidate of candidates) {
      strategy.scoreCandidate(candidate, context);
      this.assignBadges(candidate, minPriceInPool);
    }

    // Sort descending by composite score
    return candidates.sort((a, b) => b.score.compositeScore - a.score.compositeScore);
  }

  private assignBadges(candidate: MarketplaceSearchResultItem, minPrice: number): void {
    const badges: string[] = [];

    if (candidate.pricing.estimatedTotal <= minPrice * 1.05) {
      badges.push('BEST_VALUE');
    }
    if (candidate.vendor.rating >= 4.7 && candidate.vendor.reviewCount >= 10) {
      badges.push('TOP_RATED');
    }
    if (candidate.exampleVehicle.isElectric) {
      badges.push('ELECTRIC');
    }
    if (candidate.availability.instantConfirmation) {
      badges.push('INSTANT_CONFIRM');
    }
    if (candidate.score.compositeScore >= 85) {
      badges.push('POPULAR');
    }

    candidate.badges = badges;
  }
}
