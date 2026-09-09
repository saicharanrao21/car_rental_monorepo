import { Module, Global } from '@nestjs/common';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';
import { CommunicationIntelligenceService } from './communication-intelligence.service';
import { ApprovalEngineService } from './approval-engine.service';
import { SchedulingEngineService } from './scheduling-engine.service';
import { WorkflowEngineService } from './workflow-engine.service';
import { AutomationRuleEngineService } from './automation-rule-engine.service';
import { OperationsController } from './operations.controller';

@Global()
@Module({
  controllers: [OperationsController],
  providers: [
    DomainEventBusService,
    OperationsAuditTracerService,
    CommunicationIntelligenceService,
    ApprovalEngineService,
    SchedulingEngineService,
    WorkflowEngineService,
    AutomationRuleEngineService,
  ],
  exports: [
    DomainEventBusService,
    OperationsAuditTracerService,
    CommunicationIntelligenceService,
    ApprovalEngineService,
    SchedulingEngineService,
    WorkflowEngineService,
    AutomationRuleEngineService,
  ],
})
export class OperationsModule {}
