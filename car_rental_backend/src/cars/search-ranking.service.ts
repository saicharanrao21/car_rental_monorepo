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

    const scored: ScoredVehicle<T>[] = cars.map((car) => {
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
      const availabilityScore = car.isAvailable ? 1.0 : 0.0;

      // 4. Base Price Competitiveness score (normalize around price)
      const priceScore = 0.5; // baseline neutral

      // 5. Calculate base weighted composite score
      const baseScore =
        config.distanceWeight * distanceScore +
        config.ratingWeight * ratingScore +
        config.availabilityWeight * availabilityScore +
        config.relevanceWeight * priceScore;

      // 6. Multipliers for sponsored and featured placement
      const isSponsored =
        car.vendor.isSponsored === true &&
        (!car.vendor.boostExpiresAt ||
          new Date(car.vendor.boostExpiresAt) > now);

      const sponsoredMultiplier = isSponsored
        ? config.sponsoredBoostMultiplier
        : 1.0;
      const featuredMultiplier = car.isFeatured
        ? config.featuredBoostMultiplier
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
