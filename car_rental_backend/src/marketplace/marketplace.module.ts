import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { FleetModule } from '../fleet/fleet.module';
import { PricingModule } from '../pricing/pricing.module';
import { IntegrationsModule } from '../integrations/integrations.module';
import { BookingsModule } from '../bookings/bookings.module';
import { PaymentsModule } from '../payments/payments.module';

import { MarketplaceSearchService } from './marketplace-search.service';
import { MarketplaceRankingService } from './marketplace-ranking.service';
import { MarketplaceQuoteService } from './marketplace-quote.service';
import { PromotionEngineService } from './promotion-engine.service';
import { AncillaryProductsService } from './ancillary-products.service';
import { CheckoutOrchestratorService } from './checkout-orchestrator.service';
import { CancellationPreviewService } from './cancellation-preview.service';
import { MarketplaceController } from './marketplace.controller';

@Module({
  imports: [
    PrismaModule,
    FleetModule,
    PricingModule,
    IntegrationsModule,
    BookingsModule,
    PaymentsModule,
  ],
  controllers: [MarketplaceController],
  providers: [
    MarketplaceSearchService,
    MarketplaceRankingService,
    MarketplaceQuoteService,
    PromotionEngineService,
    AncillaryProductsService,
    CheckoutOrchestratorService,
    CancellationPreviewService,
  ],
  exports: [
    MarketplaceSearchService,
    MarketplaceRankingService,
    MarketplaceQuoteService,
    PromotionEngineService,
    AncillaryProductsService,
    CheckoutOrchestratorService,
    CancellationPreviewService,
  ],
})
export class MarketplaceModule {}
