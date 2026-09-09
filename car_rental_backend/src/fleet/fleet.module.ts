import { Module, forwardRef } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { IntegrationsModule } from '../integrations/integrations.module';
import { RedisModule } from '../redis/redis.module';
import { FleetController } from './fleet.controller';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import { FleetAvailabilityService } from './fleet-availability.service';
import { FleetInspectionService } from './fleet-inspection.service';
import { FleetComplianceService } from './fleet-compliance.service';
import { FleetTelematicsService } from './fleet-telematics.service';
import { FleetSearchService } from './fleet-search.service';
import { FleetIntelligenceService } from './fleet-intelligence.service';
import { VehicleAllocationService } from './vehicle-allocation.service';
import { VehicleSubstitutionService } from './vehicle-substitution.service';
import { MarketplaceSupplyService } from './marketplace-supply.service';
import { InventoryRebalancingService } from './inventory-rebalancing.service';

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    forwardRef(() => IntegrationsModule),
  ],
  controllers: [FleetController],
  providers: [
    FleetLifecycleService,
    FleetAvailabilityService,
    FleetInspectionService,
    FleetComplianceService,
    FleetTelematicsService,
    FleetSearchService,
    FleetIntelligenceService,
    VehicleAllocationService,
    VehicleSubstitutionService,
    MarketplaceSupplyService,
    InventoryRebalancingService,
  ],
  exports: [
    FleetLifecycleService,
    FleetAvailabilityService,
    FleetInspectionService,
    FleetComplianceService,
    FleetTelematicsService,
    FleetSearchService,
    FleetIntelligenceService,
    VehicleAllocationService,
    VehicleSubstitutionService,
    MarketplaceSupplyService,
    InventoryRebalancingService,
  ],
})
export class FleetModule {}
