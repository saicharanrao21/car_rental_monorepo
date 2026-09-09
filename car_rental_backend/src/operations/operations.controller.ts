import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  Req,
} from '@nestjs/common';
import { DomainEventBusService } from './domain-event-bus.service';
import { WorkflowEngineService } from './workflow-engine.service';
import { AutomationRuleEngineService } from './automation-rule-engine.service';
import { SchedulingEngineService } from './scheduling-engine.service';
import { ApprovalEngineService } from './approval-engine.service';
import { CommunicationIntelligenceService } from './communication-intelligence.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';
import {
  ApprovalDecisionDto,
  CreateApprovalRequestDto,
  CreateAutomationRuleDto,
  CreateScheduledJobDto,
  CreateWorkflowDefinitionDto,
  PublishDomainEventDto,
  RetryWorkflowDto,
  TriggerWorkflowDto,
  UpdateAutomationRuleDto,
  UpdateCommunicationPreferenceDto,
} from './operations.dto';
import { ApprovalStatus, WorkflowExecutionStatus, WorkflowStatus } from './operations-domain.types';

@Controller('api/v1/operations')
export class OperationsController {
  constructor(
    private readonly eventBus: DomainEventBusService,
    private readonly workflowEngine: WorkflowEngineService,
    private readonly ruleEngine: AutomationRuleEngineService,
    private readonly schedulingEngine: SchedulingEngineService,
    private readonly approvalEngine: ApprovalEngineService,
    private readonly commIntelligence: CommunicationIntelligenceService,
    private readonly auditTracer: OperationsAuditTracerService,
  ) {}

  // ==========================================
  // 1. WORKFLOW DEFINITIONS & EXECUTIONS
  // ==========================================

  @Get('workflows')
  getWorkflows(
    @Query('status') status?: WorkflowStatus,
    @Query('triggerEvent') triggerEvent?: string,
  ) {
    return this.workflowEngine.listDefinitions({ status, triggerEvent });
  }

  @Get('workflows/:id')
  getWorkflowById(@Param('id') id: string) {
    return this.workflowEngine.getDefinition(id);
  }

  @Post('workflows')
  createWorkflow(@Body() dto: CreateWorkflowDefinitionDto) {
    return this.workflowEngine.registerDefinition({
      workflowId: `wf_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      name: dto.name,
      description: dto.description,
      version: 1,
      triggerEvent: dto.triggerEvent,
      status: WorkflowStatus.ACTIVE,
      steps: dto.steps,
      startStepId: dto.startStepId,
      tenantScope: dto.tenantScope,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }

  @Post('workflows/:id/trigger')
  triggerWorkflow(@Param('id') id: string, @Body() dto: TriggerWorkflowDto) {
    return this.workflowEngine.triggerWorkflow({
      workflowId: id,
      payload: dto.payload || {},
      correlationId: dto.correlationId,
      causationId: dto.causationId,
      tenantContext: dto.tenantContext,
    });
  }

  @Get('executions')
  getExecutions(
    @Query('workflowId') workflowId?: string,
    @Query('status') status?: WorkflowExecutionStatus,
    @Query('correlationId') correlationId?: string,
    @Query('limit') limit?: number,
  ) {
    return this.workflowEngine.listExecutions({
      workflowId,
      status,
      correlationId,
      limit: limit ? Number(limit) : 50,
    });
  }

  @Get('executions/:id')
  getExecutionById(@Param('id') id: string) {
    return this.workflowEngine.getExecution(id);
  }

  @Post('executions/:id/retry')
  retryExecution(@Param('id') id: string, @Body() dto: RetryWorkflowDto) {
    return this.workflowEngine.retryExecution(id, dto.stepId, dto.overridePayload);
  }

  // ==========================================
  // 2. AUTOMATION RULES
  // ==========================================

  @Get('rules')
  getRules(
    @Query('triggerEvent') triggerEvent?: string,
    @Query('isEnabled') isEnabled?: string,
  ) {
    return this.ruleEngine.listRules({
      triggerEvent,
      isEnabled: isEnabled !== undefined ? isEnabled === 'true' : undefined,
    });
  }

  @Get('rules/:id')
  getRuleById(@Param('id') id: string) {
    return this.ruleEngine.getRule(id);
  }

  @Post('rules')
  createRule(@Body() dto: CreateAutomationRuleDto) {
    return this.ruleEngine.registerRule({
      ruleId: `rule_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      name: dto.name,
      description: dto.description,
      triggerEvent: dto.triggerEvent,
      predicates: dto.predicates,
      actions: dto.actions,
      priority: dto.priority ?? 10,
      isEnabled: true,
      tenantScope: dto.tenantScope,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }

  @Put('rules/:id')
  updateRule(@Param('id') id: string, @Body() dto: UpdateAutomationRuleDto) {
    const existing = this.ruleEngine.getRule(id);
    if (dto.name) existing.name = dto.name;
    if (dto.description) existing.description = dto.description;
    if (dto.predicates) existing.predicates = dto.predicates;
    if (dto.actions) existing.actions = dto.actions;
    if (dto.isEnabled !== undefined) existing.isEnabled = dto.isEnabled;
    if (dto.priority !== undefined) existing.priority = dto.priority;
    existing.updatedAt = new Date().toISOString();
    return existing;
  }

  @Delete('rules/:id')
  deleteRule(@Param('id') id: string) {
    return { success: this.ruleEngine.deleteRule(id) };
  }

  // ==========================================
  // 3. HUMAN-IN-THE-LOOP APPROVALS
  // ==========================================

  @Get('approvals')
  getApprovals(
    @Query('status') status?: ApprovalStatus,
    @Query('definitionType') definitionType?: string,
    @Query('entityType') entityType?: string,
    @Query('entityId') entityId?: string,
  ) {
    return this.approvalEngine.listApprovalRequests({
      status,
      definitionType,
      entityType,
      entityId,
    });
  }

  @Get('approvals/:id')
  getApprovalById(@Param('id') id: string) {
    return this.approvalEngine.getApprovalRequest(id);
  }

  @Post('approvals')
  createApprovalRequest(@Body() dto: CreateApprovalRequestDto) {
    return this.approvalEngine.createApprovalRequest({
      definitionType: dto.definitionType,
      entityType: dto.entityType,
      entityId: dto.entityId,
      requestedBy: { id: 'admin', role: 'ADMIN' },
      steps: dto.steps,
      metadata: dto.metadata,
      timeoutMinutes: dto.timeoutMinutes,
    });
  }

  @Post('approvals/:id/decide')
  recordApprovalDecision(
    @Param('id') id: string,
    @Body() dto: ApprovalDecisionDto,
    @Req() req: any,
  ) {
    const userId = req.user?.id || 'admin_user';
    const role = req.user?.role || 'ADMIN';

    return this.approvalEngine.recordDecision({
      requestId: id,
      stepIndex: dto.stepIndex,
      decision: dto.decision,
      decidedBy: { id: userId, role },
      decisionNote: dto.note,
    });
  }

  // ==========================================
  // 4. SCHEDULING ENGINE
  // ==========================================

  @Get('schedules')
  getSchedules(@Query('status') status?: any) {
    return this.schedulingEngine.listJobs(status);
  }

  @Post('schedules')
  createSchedule(@Body() dto: CreateScheduledJobDto) {
    return this.schedulingEngine.scheduleJob({
      name: dto.name,
      scheduleType: dto.scheduleType,
      cronExpression: dto.cronExpression,
      scheduledTime: dto.scheduledTime,
      payload: dto.payload,
      actionType: dto.actionType,
      timezone: dto.timezone,
      maxRetries: dto.maxRetries,
    });
  }

  @Delete('schedules/:id')
  cancelSchedule(@Param('id') id: string) {
    return this.schedulingEngine.cancelJob(id);
  }

  @Post('schedules/:id/run')
  runScheduleNow(@Param('id') id: string) {
    return this.schedulingEngine.executeJobNow(id);
  }

  // ==========================================
  // 5. DOMAIN EVENT STREAM & CORRELATION AUDIT
  // ==========================================

  @Get('events')
  getRecentEvents(
    @Query('eventType') eventType?: string,
    @Query('aggregateType') aggregateType?: string,
    @Query('aggregateId') aggregateId?: string,
    @Query('correlationId') correlationId?: string,
    @Query('vendorId') vendorId?: string,
    @Query('limit') limit?: number,
  ) {
    return this.eventBus.queryEvents({
      eventType,
      aggregateType,
      aggregateId,
      correlationId,
      vendorId,
      limit: limit ? Number(limit) : 50,
    });
  }

  @Post('events/publish')
  publishEvent(@Body() dto: PublishDomainEventDto) {
    return this.eventBus.emit({
      eventType: dto.eventType,
      aggregateType: dto.aggregateType,
      aggregateId: dto.aggregateId,
      payload: dto.payload,
      correlationId: dto.correlationId,
      causationId: dto.causationId,
      tenantContext: dto.tenantContext,
    });
  }

  @Get('audit/timeline/:correlationId')
  getCorrelationTimeline(@Param('correlationId') correlationId: string) {
    return this.auditTracer.getTimelineByCorrelationId(correlationId);
  }

  @Get('audit/activities')
  getRecentActivities(
    @Query('domain') domain?: string,
    @Query('status') status?: string,
    @Query('limit') limit?: number,
  ) {
    return this.auditTracer.queryTimeline({
      domain,
      status,
      limit: limit ? Number(limit) : 50,
    });
  }

  // ==========================================
  // 6. COMMUNICATION INTELLIGENCE
  // ==========================================

  @Get('communication/preferences/:userId')
  getUserPreferences(@Param('userId') userId: string) {
    return this.commIntelligence.getOrCreateProfile(userId);
  }

  @Put('communication/preferences/:userId')
  updateUserPreferences(
    @Param('userId') userId: string,
    @Body() dto: UpdateCommunicationPreferenceDto,
  ) {
    return this.commIntelligence.updatePreferences(userId, dto);
  }

  @Get('communication/predict-timing/:userId')
  predictSendTiming(@Param('userId') userId: string) {
    return this.commIntelligence.predictOptimalSendTime(userId);
  }
}
