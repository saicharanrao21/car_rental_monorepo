import { Injectable, Logger } from '@nestjs/common';
import { GeospatialService } from '../geospatial/geospatial.service';
import { SearchRankingConfig } from '../config-engine/system-config.interface';

export interface RankableVehicle {
  id: string;
  pricePerDay: number;
  isAvailable: boolean;
  vendor: {
    id: string;
    rating: number;
    isSponsored?: boolean;
    boostExpiresAt?: Date | string | null;
    latitude?: number | null;
    longitude?: number | null;
  };
  distanceKm?: number | null;
  isFeatured?: boolean;
}

export interface ScoredVehicle<T extends RankableVehicle> {
  car: T;
  distanceKm: number | null;
  scoreBreakdown: {
    distanceScore: number;
    ratingScore: number;
    priceScore: number;
    availabilityScore: number;
    sponsoredBoost: number;
    featuredBoost: number;
    finalCompositeScore: number;
  };
}

@Injectable()
export class SearchRankingService {
  private readonly logger = new Logger(SearchRankingService.name);

  constructor(private readonly geoService: GeospatialService) {}

  /**
   * Computes multi-variable ranking score and sorts vehicles.
   */
  rankVehicles<T extends RankableVehicle>(
    cars: T[],
    userLat?: number,
    userLng?: number,
    config: SearchRankingConfig = {
      relevanceWeight: 0.35,
      distanceWeight: 0.35,
      ratingWeight: 0.20,
      availabilityWeight: 0.10,
      sponsoredBoostMultiplier: 1.25,
      featuredBoostMultiplier: 1.15,
    },
    maxRadiusKm: number = 50,
  ): ScoredVehicle<T>[] {
    const hasLocation = userLat != null && userLng != null;
    const now = new Date();

    // Price distribution for dynamic competitiveness normalization
    const validPrices = cars.map((c) => c.pricePerDay).filter((p) => p > 0);
    const minPrice = validPrices.length > 0 ? Math.min(...validPrices) : 1000;
    const maxPrice = validPrices.length > 0 ? Math.max(...validPrices) : 5000;
    const priceRange = maxPrice - minPrice || 1;

    const scored: ScoredVehicle<T>[] = cars.map((car) => {
      // 0. Hard availability check: unavailable vehicles always score 0.0 and never get boosted
      if (!car.isAvailable) {
        return {
          car,
          distanceKm: null,
          scoreBreakdown: {
            distanceScore: 0,
            ratingScore: 0,
            priceScore: 0,
            availabilityScore: 0,
            sponsoredBoost: 1.0,
            featuredBoost: 1.0,
            finalCompositeScore: 0,
          },
        };
      }

      // 1. Distance calculation and score (0.0 to 1.0)
      let distanceKm: number | null = null;
      let distanceScore = 0.5; // Neutral baseline if no location provided

      if (
        hasLocation &&
        car.vendor.latitude != null &&
        car.vendor.longitude != null
      ) {
        distanceKm = this.geoService.calculateDistanceKm(
          userLat!,
          userLng!,
          car.vendor.latitude,
          car.vendor.longitude,
        );
        // Inverse linear decay: 0km -> 1.0, maxRadiusKm -> 0.0
        const normDist = Math.min(distanceKm / maxRadiusKm, 1.0);
        distanceScore = Math.max(0, 1.0 - normDist);
      }

      // 2. Rating score (0.0 to 1.0)
      const rating = car.vendor.rating || 0;
      const ratingScore = Math.min(Math.max(rating / 5.0, 0), 1.0);

      // 3. Availability score
      const availabilityScore = 1.0;

      // 4. Base Price Competitiveness score (lower relative price gets higher score)
      const priceNorm = (car.pricePerDay - minPrice) / priceRange;
      const priceScore = Math.max(0.2, 1.0 - priceNorm * 0.8); // Bounded 0.2 to 1.0

      // 5. Calculate base weighted composite score
      const baseScore =
        config.distanceWeight * distanceScore +
        config.ratingWeight * ratingScore +
        config.availabilityWeight * availabilityScore +
        config.relevanceWeight * priceScore;

      // 6. Multipliers for sponsored and featured placement (with fairness ceilings)
      const isSponsored =
        car.vendor.isSponsored === true &&
        (!car.vendor.boostExpiresAt ||
          new Date(car.vendor.boostExpiresAt) > now);

      const sponsoredMultiplier = isSponsored
        ? Math.min(Math.max(config.sponsoredBoostMultiplier, 1.0), 2.0)
        : 1.0;
      const featuredMultiplier = car.isFeatured
        ? Math.min(Math.max(config.featuredBoostMultiplier, 1.0), 1.5)
        : 1.0;

      const finalCompositeScore = Number(
        (baseScore * sponsoredMultiplier * featuredMultiplier).toFixed(4),
      );

      return {
        car,
        distanceKm,
        scoreBreakdown: {
          distanceScore: Number(distanceScore.toFixed(3)),
          ratingScore: Number(ratingScore.toFixed(3)),
          priceScore: Number(priceScore.toFixed(3)),
          availabilityScore: Number(availabilityScore.toFixed(3)),
          sponsoredBoost: sponsoredMultiplier,
          featuredBoost: featuredMultiplier,
          finalCompositeScore,
        },
      };
    });

    // Sort descending by finalCompositeScore
    scored.sort(
      (a, b) =>
        b.scoreBreakdown.finalCompositeScore -
        a.scoreBreakdown.finalCompositeScore,
    );

    return scored;
  }
}
