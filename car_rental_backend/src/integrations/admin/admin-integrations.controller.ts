import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
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
import { AdminIntegrationsService } from './admin-integrations.service';
import { IntegrationCategory } from '../registry/provider.types';
import {
  ProviderActivationState,
  ProviderEnvironment,
} from '../catalog/provider-catalog.types';
import {
  UpdateIntegrationConfigDto,
  ToggleProviderDto,
  SetActiveProviderDto,
  TestConnectionDto,
  RegisterCatalogProviderDto,
  UpdateActivationStateDto,
  ValidateCredentialsDto,
} from './dto/admin-integrations.dto';
import {
  IntegrationExecutionRequest,
  ProviderPolicyRule,
  SimulationScenario,
} from '../runtime/runtime.types';

@Controller('admin/integrations')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminIntegrationsController {
  constructor(private readonly integrationsService: AdminIntegrationsService) {}

  @Get('overview')
  async getOverview(
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
  ) {
    return this.integrationsService.getOverview({ vendorId, branchId });
  }

  @Get('providers')
  async listProviders(
    @Query('category') category?: IntegrationCategory,
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
  ) {
    return this.integrationsService.listProviders(category, { vendorId, branchId });
  }

  @Get('providers/:category/:providerId')
  async getProviderDetails(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
  ) {
    return this.integrationsService.getProviderDetails(category, providerId, {
      vendorId,
      branchId,
    });
  }

  @Put('providers/:category/:providerId/config')
  async updateConfig(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: UpdateIntegrationConfigDto,
    @Req() req: any,
  ) {
    return this.integrationsService.updateProviderConfig(
      category,
      providerId,
      dto,
      req.user?.id,
    );
  }

  @Post('providers/:category/:providerId/set-active')
  async setActive(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: SetActiveProviderDto,
    @Req() req: any,
  ) {
    await this.integrationsService.setActiveProvider(
      category,
      providerId,
      req.user?.id,
      { vendorId: dto.vendorId, branchId: dto.branchId },
    );
    return { success: true, message: `Active provider set to ${providerId}` };
  }

  @Post('providers/:category/:providerId/toggle')
  async toggleProvider(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: ToggleProviderDto,
  ) {
    this.integrationsService.toggleProvider(category, providerId, dto.enabled);
    return { success: true, isEnabled: dto.enabled };
  }

  @Post('providers/:category/:providerId/test')
  async testConnection(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: TestConnectionDto,
  ) {
    return this.integrationsService.testConnection(category, providerId, dto, {
      vendorId: dto.vendorId,
      branchId: dto.branchId,
    });
  }

  @Get('webhooks')
  async listWebhooks(
    @Query('gateway') gateway?: string,
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('skip') skip?: number,
  ) {
    return this.integrationsService.listWebhookEvents({
      gateway,
      status,
      limit: limit ? Number(limit) : 50,
      skip: skip ? Number(skip) : 0,
    });
  }

  @Post('webhooks/:eventId/replay')
  async replayWebhook(@Param('eventId') eventId: string) {
    return this.integrationsService.replayWebhookEvent(eventId);
  }

  // =========================================================================
  // PHASE J: MARKETPLACE & CATALOG ENDPOINTS
  // =========================================================================

  @Get('marketplace')
  async getMarketplace(
    @Query('category') category?: IntegrationCategory,
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
    @Query('tenantTier') tenantTier?: string,
    @Query('environment') environment?: ProviderEnvironment,
    @Query('search') search?: string,
  ) {
    return this.integrationsService.getMarketplace({
      category,
      vendorId,
      branchId,
      tenantTier,
      environment,
      search,
    });
  }

  @Get('catalog')
  async getCatalog(
    @Query('category') category?: IntegrationCategory,
    @Query('capability') capability?: string,
    @Query('country') country?: string,
    @Query('currency') currency?: string,
    @Query('environment') environment?: ProviderEnvironment,
    @Query('activationState') activationState?: ProviderActivationState,
    @Query('tenantTier') tenantTier?: string,
    @Query('search') search?: string,
  ) {
    return this.integrationsService.getCatalog({
      category,
      capability,
      country,
      currency,
      environment,
      activationState,
      tenantTier,
      search,
    });
  }

  @Post('catalog')
  async registerCatalogProvider(@Body() dto: RegisterCatalogProviderDto) {
    return this.integrationsService.registerCatalogProvider(dto);
  }

  @Get('catalog/:category/:providerId')
  async getCatalogProvider(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
  ) {
    return this.integrationsService.getCatalogProvider(category, providerId);
  }

  @Put('catalog/:category/:providerId/activation')
  async updateActivationState(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: UpdateActivationStateDto,
  ) {
    return this.integrationsService.updateActivationState(
      category,
      providerId,
      dto.activationState as ProviderActivationState,
    );
  }

  @Post('catalog/:category/:providerId/validate')
  async validateCredentials(
    @Param('category') category: IntegrationCategory,
    @Param('providerId') providerId: string,
    @Body() dto: ValidateCredentialsDto,
  ) {
    return this.integrationsService.validateCredentials(category, providerId, dto);
  }

  @Get('fallback-chain/:category')
  async getFallbackChain(
    @Param('category') category: IntegrationCategory,
    @Query('region') region?: string,
    @Query('currency') currency?: string,
    @Query('environment') environment?: ProviderEnvironment,
    @Query('tenantTier') tenantTier?: string,
  ) {
    return this.integrationsService.resolveFallbackChain(category, {
      region,
      currency,
      environment,
      tenantTier,
    });
  }

  // =========================================================================
  // PHASE K: RUNTIME CONTROL CENTRE & FAILOVER MANAGEMENT
  // =========================================================================

  @Get('runtime/overview')
  async getRuntimeOverview(
    @Query('vendorId') vendorId?: string,
    @Query('branchId') branchId?: string,
  ) {
    return this.integrationsService.getRuntimeOverview({ vendorId, branchId });
  }

  @Get('runtime/circuits')
  async getCircuits() {
    return this.integrationsService.getCircuitStates();
  }

  @Post('runtime/circuits/:providerId/reset')
  async resetCircuit(@Param('providerId') providerId: string) {
    this.integrationsService.resetCircuit(providerId);
    return { success: true, message: `Circuit for ${providerId} reset to CLOSED` };
  }

  @Post('runtime/circuits/:providerId/trip')
  async tripCircuit(
    @Param('providerId') providerId: string,
    @Body('reason') reason?: string,
  ) {
    this.integrationsService.tripCircuit(providerId, reason);
    return { success: true, message: `Circuit for ${providerId} manually tripped to OPEN` };
  }

  @Get('runtime/simulations/:providerId')
  async getSimulation(@Param('providerId') providerId: string) {
    return { providerId, scenario: this.integrationsService.getSimulation(providerId) };
  }

  @Post('runtime/simulations/:providerId')
  async setSimulation(
    @Param('providerId') providerId: string,
    @Body('scenario') scenario: SimulationScenario,
  ) {
    this.integrationsService.setSimulation(providerId, scenario);
    return { success: true, providerId, scenario };
  }

  @Delete('runtime/simulations/:providerId')
  async clearSimulation(@Param('providerId') providerId: string) {
    this.integrationsService.clearSimulation(providerId);
    return { success: true, message: `Simulation cleared for ${providerId}` };
  }

  @Get('runtime/policies')
  async getPolicies() {
    return this.integrationsService.getPolicies();
  }

  @Post('runtime/policies')
  async upsertPolicy(@Body() policy: any) {
    this.integrationsService.upsertPolicy(policy);
    return { success: true, policy };
  }

  @Delete('runtime/policies/:id')
  async deletePolicy(@Param('id') id: string) {
    this.integrationsService.deletePolicy(id);
    return { success: true, message: `Policy ${id} deleted` };
  }

  @Get('runtime/incidents')
  async getIncidents(
    @Query('providerId') providerId?: string,
    @Query('status') status?: string,
  ) {
    return this.integrationsService.getIncidents({ providerId, status });
  }

  @Post('runtime/incidents/:providerId/resolve')
  async resolveIncident(
    @Param('providerId') providerId: string,
    @Body('reason') reason?: string,
  ) {
    this.integrationsService.resolveIncident(providerId, reason);
    return { success: true, message: `Incident for ${providerId} marked RESOLVED` };
  }

  @Get('runtime/executions')
  async getExecutions(
    @Query('category') category?: string,
    @Query('providerId') providerId?: string,
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.integrationsService.getExecutions({
      category,
      providerId,
      status,
      limit: limit ? Number(limit) : 50,
      offset: offset ? Number(offset) : 0,
    });
  }

  @Post('runtime/execute')
  async executeRuntime(@Body() request: any) {
    return this.integrationsService.executeRuntime(request);
  }
}
