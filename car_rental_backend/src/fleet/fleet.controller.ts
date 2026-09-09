import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import { FleetAvailabilityService } from './fleet-availability.service';
import { FleetInspectionService, SubmitInspectionDto } from './fleet-inspection.service';
import { FleetComplianceService, RegisterComplianceDocumentDto } from './fleet-compliance.service';
import { FleetTelematicsService, IngestTelemetryDto } from './fleet-telematics.service';
import { FleetSearchService, FleetSearchFilters } from './fleet-search.service';
import { FleetIntelligenceService } from './fleet-intelligence.service';
import { FleetOperationalState } from './fleet-domain.types';

@Controller('api/v1/fleet')
export class FleetController {
  constructor(
    private readonly lifecycleService: FleetLifecycleService,
    private readonly availabilityService: FleetAvailabilityService,
    private readonly inspectionService: FleetInspectionService,
    private readonly complianceService: FleetComplianceService,
    private readonly telematicsService: FleetTelematicsService,
    private readonly searchService: FleetSearchService,
    private readonly intelligenceService: FleetIntelligenceService,
  ) {}

  // 1. Executive Dashboard KPIs
  @Get('kpis')
  async getFleetKpis(@Query('vendorId') vendorId?: string) {
    return this.intelligenceService.getFleetKpis(vendorId);
  }

  // 2. Branch Rebalancing Recommendations
  @Get('rebalance-recommendations')
  async getRebalanceRecommendations() {
    return this.intelligenceService.generateBranchRebalanceRecommendations();
  }

  // 3. Enterprise Search & Discovery
  @Get('search')
  async searchFleet(@Query() query: FleetSearchFilters) {
    return this.searchService.searchFleet(query);
  }

  // 4. Vehicle Explainable Availability
  @Get(':carId/availability')
  async getVehicleAvailability(
    @Param('carId') carId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    const interval = startDate && endDate ? { startDate: new Date(startDate), endDate: new Date(endDate) } : undefined;
    return this.availabilityService.explainAvailability(carId, interval);
  }

  // 5. Vehicle Operational State & Audit
  @Get(':carId/state')
  async getVehicleState(@Param('carId') carId: string) {
    const state = await this.lifecycleService.getVehicleState(carId);
    return { carId, state };
  }

  @Post(':carId/transition')
  async transitionState(
    @Param('carId') carId: string,
    @Body('targetState') targetState: FleetOperationalState,
    @Body('reason') reason: string,
    @Body('metadata') metadata: Record<string, any>,
    @Req() req: any,
  ) {
    const actor = {
      id: req.user?.id || 'admin_operator',
      role: req.user?.role || 'ADMIN',
    };
    return this.lifecycleService.transitionState(carId, targetState, actor as any, {
      reason: reason || 'Operational transition requested via Fleet Command Centre',
      metadata,
    });
  }

  @Get(':carId/audit-trail')
  async getAuditTrail(@Param('carId') carId: string) {
    return this.lifecycleService.getAuditHistory(carId);
  }

  // 6. 16-Point Inspection Subsystem
  @Get('inspection-template')
  getInspectionTemplate() {
    return this.inspectionService.getStandard16PointTemplate();
  }

  @Post('inspections')
  async recordInspection(@Body() dto: SubmitInspectionDto) {
    return this.inspectionService.recordInspection(dto);
  }

  @Get(':carId/inspections')
  async getVehicleInspections(@Param('carId') carId: string) {
    return this.inspectionService.getInspectionHistory(carId);
  }

  @Post('damage-analysis')
  async analyzeDamagePhotos(@Body('photoUrls') photoUrls: string[]) {
    return this.inspectionService.analyzeDamagePhotos(photoUrls || []);
  }

  // 7. Compliance & Regulatory Documents
  @Post('compliance')
  async registerComplianceDocument(@Body() dto: RegisterComplianceDocumentDto) {
    return this.complianceService.registerDocument(dto);
  }

  @Get(':carId/compliance')
  async getVehicleCompliance(@Param('carId') carId: string) {
    return this.complianceService.evaluateVehicleCompliance(carId);
  }

  @Get(':carId/documents')
  async getVehicleDocuments(@Param('carId') carId: string) {
    return this.complianceService.getDocuments(carId);
  }

  // 8. Telematics & IoT Ingestion
  @Post('telemetry')
  async ingestTelemetry(@Body() dto: IngestTelemetryDto) {
    return this.telematicsService.ingestTelemetry(dto);
  }

  @Get(':carId/telemetry')
  async getLatestTelemetry(@Param('carId') carId: string) {
    return this.telematicsService.getLatestTelemetry(carId);
  }

  @Post(':carId/immobilize')
  async immobilizeVehicle(
    @Param('carId') carId: string,
    @Body('reason') reason: string,
  ) {
    return this.telematicsService.immobilizeVehicle(
      carId,
      reason || 'Emergency remote immobilization initiated by security operator',
    );
  }
}
