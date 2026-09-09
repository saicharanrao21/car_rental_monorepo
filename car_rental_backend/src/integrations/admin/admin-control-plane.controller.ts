import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { IntegrationCategory } from '../registry/provider.types';
import { ProviderDirectoryService } from '../directory/provider-directory.service';
import { CapabilityMatrixService } from '../directory/capability-matrix.service';
import { ProviderScoringService } from '../scoring/provider-scoring.service';
import { ProviderIncidentService } from '../governance/provider-incident.service';
import { ProviderChangeAuditService } from '../governance/provider-change-audit.service';
import { ProviderRecommendationService } from '../governance/provider-recommendation.service';
import { ProviderOnboardingService } from '../directory/provider-onboarding.service';
import { ProviderSimulationService } from '../runtime/provider-simulation.service';
import { ProviderRoutingService } from '../runtime/provider-routing.service';
import {
  CreateManualIncidentDto,
  DirectoryFilterDto,
  ManualChangeAuditDto,
  OnboardingSubmitDto,
  ResolveIncidentDto,
  RunSimulationLabDto,
  ScoreCompareDto,
  UpdateIncidentStatusDto,
} from './dto/control-plane.dto';
import { DetectionSource } from '../governance/provider-incident.types';

@Controller('admin/integrations/control-plane')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminControlPlaneController {
  constructor(
    private readonly directoryService: ProviderDirectoryService,
    private readonly capabilityService: CapabilityMatrixService,
    private readonly scoringService: ProviderScoringService,
    private readonly incidentService: ProviderIncidentService,
    private readonly changeAuditService: ProviderChangeAuditService,
    private readonly recommendationService: ProviderRecommendationService,
    private readonly onboardingService: ProviderOnboardingService,
    private readonly simulationService: ProviderSimulationService,
    private readonly routingService: ProviderRoutingService,
  ) {}

  // =========================================================================
  // 1. OVERVIEW & KPI METRICS
  // =========================================================================

  @Get('overview')
  async getControlPlaneOverview() {
    const allProviders = this.directoryService.findProviders();
    const activeProviders = allProviders.filter((p) => p.status === 'ACTIVE');
    const incidentStats = this.incidentService.getIncidentStats();
    const recommendations = this.recommendationService.getRecommendations();

    const categories = Array.from(new Set(allProviders.map((p) => p.category)));

    return {
      success: true,
      timestamp: new Date().toISOString(),
      kpis: {
        totalProviders: allProviders.length,
        activeProviders: activeProviders.length,
        monitoredCategories: categories.length,
        activeIncidents: incidentStats.activeIncidents,
        criticalIncidents: incidentStats.bySeverity['CRITICAL'] || 0,
        pendingRecommendations: recommendations.filter((r) => r.status === 'PENDING').length,
      },
      categories,
      incidentSummary: incidentStats,
    };
  }

  // =========================================================================
  // 2. PROVIDER DIRECTORY & CAPABILITIES
  // =========================================================================

  @Get('directory')
  async listDirectory(@Query() query: DirectoryFilterDto) {
    const results = this.directoryService.findProviders(query);
    return {
      success: true,
      count: results.length,
      providers: results,
    };
  }

  @Get('directory/:providerId')
  async getDirectoryProvider(@Param('providerId') providerId: string) {
    const provider = this.directoryService.getProvider(providerId);
    return {
      success: true,
      provider,
    };
  }

  @Get('capabilities')
  async listCapabilities(@Query('category') category?: IntegrationCategory) {
    if (category) {
      const caps = this.capabilityService.getCapabilitiesForCategory(category);
      return { success: true, category, capabilities: caps };
    }
    const all = this.capabilityService.getAllNormalizedCapabilities();
    return { success: true, capabilities: all };
  }

  // =========================================================================
  // 3. DETERMINISTIC MULTI-FACTOR SCORING
  // =========================================================================

  @Post('scoring/compare')
  async compareProviderScores(@Body() dto: ScoreCompareDto) {
    const providers = this.directoryService.findProviders({ category: dto.category });

    const scored = providers.map((p) => {
      const scoreBreakdown = this.scoringService.calculateScore(p, {
        category: dto.category,
        country: dto.country,
        currency: dto.currency,
        requiredCapabilities: dto.requiredCapabilities,
        maxAcceptableLatencyMs: dto.maxAcceptableLatencyMs || 1000,
      });
      return {
        providerId: p.providerId,
        displayName: p.displayName,
        score: scoreBreakdown.finalScore,
        breakdown: scoreBreakdown,
      };
    });

    scored.sort((a, b) => b.score - a.score);

    return {
      success: true,
      category: dto.category,
      ranking: scored,
    };
  }

  @Get('scoring/:category/:providerId')
  async getProviderScore(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Query('country') country?: string,
    @Query('currency') currency?: string,
  ) {
    const provider = this.directoryService.getProvider(providerId);
    const score = this.scoringService.calculateScore(provider, {
      category,
      country,
      currency,
    });

    return {
      success: true,
      providerId,
      score,
    };
  }

  // =========================================================================
  // 4. INCIDENT DESK
  // =========================================================================

  @Get('incidents')
  async listIncidents(
    @Query('providerId') providerId?: string,
    @Query('category') category?: IntegrationCategory,
    @Query('status') status?: any,
    @Query('severity') severity?: any,
  ) {
    const incidents = this.incidentService.queryIncidents({
      providerId,
      category,
      status,
      severity,
    });
    return {
      success: true,
      count: incidents.length,
      incidents,
    };
  }

  @Get('incidents/stats')
  async getIncidentStats() {
    return {
      success: true,
      stats: this.incidentService.getIncidentStats(),
    };
  }

  @Post('incidents')
  async createManualIncident(@Body() dto: CreateManualIncidentDto, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const incident = await this.incidentService.createIncident({
      providerId: dto.providerId,
      category: dto.category,
      title: dto.title,
      severity: dto.severity,
      incidentType: dto.incidentType,
      detectionSource: DetectionSource.ADMIN_MANUAL,
      reason: dto.reason,
      metadata: {
        ...dto.metadata,
        createdByUser: actorId,
      },
    });

    return {
      success: true,
      message: 'Incident successfully recorded',
      incident,
    };
  }

  @Post('incidents/:id/acknowledge')
  async acknowledgeIncident(@Param('id') id: string, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const incident = await this.incidentService.acknowledgeIncident(id, actorId);
    return {
      success: true,
      message: 'Incident acknowledged',
      incident,
    };
  }

  @Post('incidents/:id/resolve')
  async resolveIncident(
    @Param('id') id: string,
    @Body() dto: ResolveIncidentDto,
    @Req() req: any,
  ) {
    const actorId = req.user?.id || 'admin_operator';
    const incident = await this.incidentService.resolveIncident(id, actorId, dto.resolutionNotes);
    return {
      success: true,
      message: 'Incident resolved',
      incident,
    };
  }

  // =========================================================================
  // 5. CHANGE AUDIT TRAIL
  // =========================================================================

  @Get('governance/changes')
  async getChangeHistory(
    @Query('providerId') providerId?: string,
    @Query('category') category?: IntegrationCategory,
    @Query('changeType') changeType?: any,
  ) {
    const history = this.changeAuditService.queryChangeHistory({
      providerId,
      category,
      changeType,
    });
    return {
      success: true,
      count: history.length,
      history,
    };
  }

  @Post('governance/changes')
  async recordManualChange(@Body() dto: ManualChangeAuditDto, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const actorRole = req.user?.role || 'ADMIN';

    const recorded = await this.changeAuditService.recordChange({
      providerId: dto.providerId,
      category: dto.category,
      changeType: dto.changeType,
      environment: dto.environment,
      actorId,
      actorRole,
      reason: dto.reason,
      beforeSnapshot: dto.beforeSnapshot,
      afterSnapshot: dto.afterSnapshot,
    });

    return {
      success: true,
      message: 'Change event audited',
      record: recorded,
    };
  }

  // =========================================================================
  // 6. RECOMMENDATIONS & AUTOMATION BOUNDARIES
  // =========================================================================

  @Get('recommendations')
  async listRecommendations(@Query('status') status?: any) {
    const recs = this.recommendationService.getRecommendations(status);
    return {
      success: true,
      count: recs.length,
      recommendations: recs,
    };
  }

  @Post('recommendations/scan')
  async triggerRecommendationScan() {
    const generated = this.recommendationService.generateRecommendations();
    return {
      success: true,
      message: 'Scanned environment and updated recommendations',
      count: generated.length,
      recommendations: generated,
    };
  }

  @Post('recommendations/:id/approve')
  async approveRecommendation(@Param('id') id: string, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const rec = await this.recommendationService.approveRecommendation(id, actorId);
    return {
      success: true,
      message: 'Recommendation approved',
      recommendation: rec,
    };
  }

  @Post('recommendations/:id/dismiss')
  async dismissRecommendation(@Param('id') id: string, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const rec = await this.recommendationService.dismissRecommendation(id, actorId);
    return {
      success: true,
      message: 'Recommendation dismissed',
      recommendation: rec,
    };
  }

  // =========================================================================
  // 7. PROVIDER ONBOARDING PIPELINE
  // =========================================================================

  @Post('onboarding/validate')
  async validateOnboarding(@Body() dto: OnboardingSubmitDto) {
    const validation = this.onboardingService.validateDefinition(dto as any);
    return {
      success: validation.isValid,
      errors: validation.errors,
      warnings: validation.warnings,
    };
  }

  @Post('onboarding/submit')
  async submitOnboarding(@Body() dto: OnboardingSubmitDto, @Req() req: any) {
    const actorId = req.user?.id || 'admin_operator';
    const actorRole = req.user?.role || 'ADMIN';

    const registered = await this.onboardingService.submitOnboarding(
      dto as any,
      actorId,
      actorRole,
    );

    return {
      success: true,
      message: `Provider '${registered.displayName}' successfully onboarded and registered.`,
      provider: registered,
    };
  }

  // =========================================================================
  // 8. SIMULATION TEST LAB
  // =========================================================================

  @Post('simulation/lab')
  async runSimulationLab(@Body() dto: RunSimulationLabDto) {
    const result = await this.simulationService.simulateExecution(
      dto.providerId,
      dto.category,
      dto.scenario,
      {
        injectedLatencyMs: dto.latencyMs,
        customPayload: dto.payload,
      },
    );

    return {
      success: true,
      simulationResult: result,
    };
  }
}
