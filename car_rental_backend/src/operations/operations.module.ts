import { Module, Global, forwardRef } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { DomainEventBusService } from './domain-event-bus.service';
import { OperationsAuditTracerService } from './operations-audit-tracer.service';
import { CommunicationIntelligenceService } from './communication-intelligence.service';
import { ApprovalEngineService } from './approval-engine.service';
import { SchedulingEngineService } from './scheduling-engine.service';
import { WorkflowEngineService } from './workflow-engine.service';
import { AutomationRuleEngineService } from './automation-rule-engine.service';
import { BranchOperationsService } from './branch-operations.service';
import { SlaEscalationEngineService } from './sla-escalation.service';
import { OperationsController } from './operations.controller';
import { CommandCenterController } from './command-center.controller';
import { FulfillmentModule } from '../fulfillment/fulfillment.module';
import { FleetModule } from '../fleet/fleet.module';

@Global()
@Module({
  imports: [
    PrismaModule,
    forwardRef(() => FulfillmentModule),
    forwardRef(() => FleetModule),
  ],
  controllers: [OperationsController, CommandCenterController],
  providers: [
    DomainEventBusService,
    OperationsAuditTracerService,
    CommunicationIntelligenceService,
    ApprovalEngineService,
    SchedulingEngineService,
    WorkflowEngineService,
    AutomationRuleEngineService,
    BranchOperationsService,
    SlaEscalationEngineService,
  ],
  exports: [
    DomainEventBusService,
    OperationsAuditTracerService,
    CommunicationIntelligenceService,
    ApprovalEngineService,
    SchedulingEngineService,
    WorkflowEngineService,
    AutomationRuleEngineService,
    BranchOperationsService,
    SlaEscalationEngineService,
  ],
})
export class OperationsModule {}
