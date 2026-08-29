import { SearchRankingService, RankableVehicle } from './search-ranking.service';
import { GeospatialService } from '../geospatial/geospatial.service';
import { SearchRankingConfig } from '../config-engine/system-config.interface';

describe('Phase 27.1 — Search Ranking & Multi-Variable Scoring Pipeline Tests', () => {
  let rankingService: SearchRankingService;
  let geoService: GeospatialService;

  beforeEach(() => {
    geoService = new GeospatialService();
    rankingService = new SearchRankingService(geoService);
  });

  const sampleCars: RankableVehicle[] = [
    {
      id: 'car_far_high_rated',
      pricePerDay: 2500,
      isAvailable: true,
      vendor: {
        id: 'v_pune',
        rating: 4.9,
        latitude: 18.5204,
        longitude: 73.8567, // ~120km from Mumbai
        isSponsored: false,
      },
    },
    {
      id: 'car_near_med_rated',
      pricePerDay: 2200,
      isAvailable: true,
      vendor: {
        id: 'v_bandra',
        rating: 4.2,
        latitude: 19.0596,
        longitude: 72.8295, // ~5km from Mumbai
        isSponsored: false,
      },
    },
    {
      id: 'car_near_sponsored',
      pricePerDay: 2400,
      isAvailable: true,
      vendor: {
        id: 'v_andheri',
        rating: 4.5,
        latitude: 19.1136,
        longitude: 72.8697, // ~8km from Mumbai
        isSponsored: true,
        boostExpiresAt: new Date(Date.now() + 86400000), // Active 24h
      },
    },
  ];

  const defaultConfig: SearchRankingConfig = {
    relevanceWeight: 0.25,
    distanceWeight: 0.40,
    ratingWeight: 0.25,
    availabilityWeight: 0.10,
    sponsoredBoostMultiplier: 1.25,
    featuredBoostMultiplier: 1.15,
  };

  it('ranks closer and sponsored vehicles higher when location is provided', () => {
    const mumbaiLat = 19.076;
    const mumbaiLng = 72.8777;

    const ranked = rankingService.rankVehicles(
      sampleCars,
      mumbaiLat,
      mumbaiLng,
      defaultConfig,
      100, // 100km radius
    );

    expect(ranked.length).toBe(3);
    // The sponsored near car should have the highest score
    expect(ranked[0].car.id).toBe('car_near_sponsored');
    expect(ranked[0].scoreBreakdown.sponsoredBoost).toBe(1.25);
    expect(ranked[0].distanceKm).toBeLessThan(15);

    // Far car should have low distance score despite high rating
    const farCar = ranked.find((c) => c.car.id === 'car_far_high_rated');
    expect(farCar).toBeDefined();
    expect(farCar!.scoreBreakdown.distanceScore).toBe(0); // Exceeds 100km normalized
  });

  it('falls back to rating and price relevance when location is not provided', () => {
    const ranked = rankingService.rankVehicles(
      sampleCars,
      undefined,
      undefined,
      defaultConfig,
    );

    expect(ranked.length).toBe(3);
    for (const r of ranked) {
      expect(r.distanceKm).toBeNull();
      expect(r.scoreBreakdown.distanceScore).toBe(0.5); // Baseline neutral
    }
  });

  it('correctly applies featured boost multiplier', () => {
    const featuredCar: RankableVehicle = {
      id: 'car_featured',
      pricePerDay: 2000,
      isAvailable: true,
      isFeatured: true,
      vendor: {
        id: 'v_featured',
        rating: 4.8,
        latitude: 19.076,
        longitude: 72.8777,
      },
    };

    const ranked = rankingService.rankVehicles([featuredCar], 19.076, 72.8777, defaultConfig);
    expect(ranked[0].scoreBreakdown.featuredBoost).toBe(1.15);
  });
});
