import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CarCategory } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface CompetitorPriceSignal {
  providerSource: string; // "OTA_FEED", "MAKEMYTRIP", "ZOOMCAR_MARKET", "CAR_HIRE_GLOBAL", "MANUAL_SURVEY"
  city: string;
  vehicleClass: CarCategory;
  competitorName: string;
  observedDailyPrice: number;
  currency?: string;
  confidenceScore?: number;
  observedAt?: Date;
  metadata?: Record<string, any>;
}

export interface MarketPriceIndex {
  city: string;
  vehicleClass: CarCategory;
  medianPrice: number;
  minPrice: number;
  maxPrice: number;
  sampleCount: number;
  confidenceScore: number;
  lastUpdated: string;
}

export interface ICompetitivePriceProvider {
  readonly providerId: string;
  fetchMarketSignals(city: string, vehicleClass?: CarCategory): Promise<CompetitorPriceSignal[]>;
}

@Injectable()
export class CompetitivePricingService {
  private readonly logger = new Logger(CompetitivePricingService.name);
  private readonly registeredProviders: Map<string, ICompetitivePriceProvider> = new Map();

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Registers a third-party market intelligence provider
   */
  registerProvider(provider: ICompetitivePriceProvider) {
    this.registeredProviders.set(provider.providerId, provider);
    this.logger.log(`Registered competitive price provider: ${provider.providerId}`);
  }

  /**
   * Ingests a normalized market price observation into persistent storage
   */
  async recordObservation(signal: CompetitorPriceSignal) {
    return this.prisma.competitorPriceObservation.create({
      data: {
        providerSource: signal.providerSource,
        city: signal.city.toUpperCase(),
        vehicleClass: signal.vehicleClass,
        competitorName: signal.competitorName,
        observedDailyPrice: new Decimal(signal.observedDailyPrice),
        currency: signal.currency || 'INR',
        confidenceScore: signal.confidenceScore ?? 0.90,
        observedAt: signal.observedAt || new Date(),
        metadata: signal.metadata,
      },
    });
  }

  /**
   * Computes a normalized market price index for a city and vehicle category based on recent signals
   */
  async getMarketPriceIndex(city: string, vehicleClass: CarCategory, windowDays = 7): Promise<MarketPriceIndex | null> {
    const threshold = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

    const observations = await this.prisma.competitorPriceObservation.findMany({
      where: {
        city: city.toUpperCase(),
        vehicleClass,
        observedAt: { gte: threshold },
      },
      orderBy: { observedAt: 'desc' },
      take: 50,
    });

    if (observations.length === 0) {
      return null;
    }

    const prices = observations.map((o) => Number(o.observedDailyPrice)).sort((a, b) => a - b);
    const minPrice = prices[0];
    const maxPrice = prices[prices.length - 1];
    const medianPrice = prices[Math.floor(prices.length / 2)];
    const avgConfidence =
      observations.reduce((sum, o) => sum + o.confidenceScore, 0) / observations.length;

    return {
      city: city.toUpperCase(),
      vehicleClass,
      medianPrice,
      minPrice,
      maxPrice,
      sampleCount: observations.length,
      confidenceScore: Math.round(avgConfidence * 100) / 100,
      lastUpdated: observations[0].observedAt.toISOString(),
    };
  }
}
