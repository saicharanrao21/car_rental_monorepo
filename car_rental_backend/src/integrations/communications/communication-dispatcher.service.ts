import {
  Injectable,
  Logger,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IntegrationRuntimeService } from '../runtime/integration-runtime.service';
import { CommunicationComplianceService } from './communication-compliance.service';
import { CommunicationTemplateEngine } from './communication-template.engine';
import { CommunicationRoutingService } from './communication-routing.service';
import {
  CommunicationRequest,
  CommunicationResponse,
  CommunicationChannel,
  DeliveryStatus,
  CommunicationPriority,
} from './communication.types';

@Injectable()
export class CommunicationDispatcherService {
  private readonly logger = new Logger(CommunicationDispatcherService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly runtimeService: IntegrationRuntimeService,
    private readonly complianceService: CommunicationComplianceService,
    private readonly templateEngine: CommunicationTemplateEngine,
    private readonly routingService: CommunicationRoutingService,
  ) {}

  /**
   * Dispatches an enterprise communication across the optimal channel and provider.
   * Enforces consent, DND, quiet hours, template rendering, multi-factor routing, and lifecycle states.
   */
  async dispatchCommunication(request: CommunicationRequest): Promise<CommunicationResponse> {
    const startTime = Date.now();
    const communicationId = `comm_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // 1. Initial State: CREATED
    this.logger.log(`[COMM_DISPATCHER] Initiating communication [${communicationId}] type=[${request.messageType}]`);

    // 2. Resolve Channel & Provider Route
    const route = await this.routingService.resolveCommunicationRoute({
      channel: request.channel,
      messageType: request.messageType,
      priority: request.priority,
      recipient: request.recipient,
      tenantId: request.tenantId,
      vendorId: request.vendorId,
      branchId: request.branchId,
    });

    const activeChannel = route.channel;

    // 3. Compliance & Consent Check
    const compliance = this.complianceService.evaluateCompliance({
      channel: activeChannel,
      messageType: request.messageType,
      priority: request.priority,
      recipient: request.recipient,
    });

    if (!compliance.allowed) {
      this.logger.warn(`[COMM_DISPATCHER] Communication blocked by compliance: ${compliance.reason}`);
      return {
        success: false,
        communicationId,
        channel: activeChannel,
        providerId: route.primaryProviderId,
        status: DeliveryStatus.CANCELLED,
        attemptsCount: 0,
        costEstimate: 0,
        latencyMs: Date.now() - startTime,
        explanation: `Blocked: ${compliance.reason}`,
        error: compliance.reason,
      };
    }

    // 4. Render Localized Template if template specified
    let renderedSubject = request.directContent?.subject;
    let renderedBody = request.directContent?.body;
    let renderedHtml = request.directContent?.html;
    let dltTemplateId = request.template?.dltTemplateId;
    let buttons = request.template?.buttons;

    if (request.template) {
      const rendered = this.templateEngine.renderTemplate({
        channel: activeChannel,
        templateName: request.template.templateName,
        language: request.template.language || request.recipient.language,
        variables: {
          ...request.template.variables,
          customerName: request.recipient.name || 'Customer',
          otpCode: request.otpCode || '',
        },
      });

      renderedSubject = rendered.subject || renderedSubject;
      renderedBody = rendered.body;
      renderedHtml = rendered.html || renderedHtml;
      dltTemplateId = rendered.dltTemplateId || dltTemplateId;
      buttons = rendered.buttons || buttons;
    }

    // 5. Construct Normalized Provider Payload based on Channel
    const category = this.routingService.mapChannelToCategory(activeChannel);
    let payload: any;
    let capability = 'SEND_MESSAGE';

    switch (activeChannel) {
      case CommunicationChannel.WHATSAPP:
        capability = 'SEND_TEMPLATE';
        payload = {
          to: request.recipient.phone,
          templateName: request.template?.templateName || 'generic_notification',
          language: request.template?.language || request.recipient.language || 'en',
          bodyParameters: request.template?.variables
            ? Object.values(request.template.variables).map(String)
            : [renderedBody || ''],
          buttons,
          idempotencyKey: request.idempotencyKey,
        };
        break;

      case CommunicationChannel.SMS:
      case CommunicationChannel.OTP:
        capability = request.otpCode ? 'SEND_OTP' : 'SEND_SMS';
        payload = {
          to: request.recipient.phone,
          message: renderedBody || 'Notification from DriveGo',
          otpCode: request.otpCode,
          templateId: dltTemplateId,
          isTransactional: request.messageType !== 'MARKETING',
          idempotencyKey: request.idempotencyKey,
        };
        break;

      case CommunicationChannel.EMAIL:
        capability = 'SEND_EMAIL';
        payload = {
          to: request.recipient.email,
          subject: renderedSubject || 'DriveGo Notification',
          html: renderedHtml || `<p>${renderedBody}</p>`,
          attachments: request.directContent?.attachments,
          idempotencyKey: request.idempotencyKey,
        };
        break;

      case CommunicationChannel.PUSH:
        capability = 'SEND_PUSH';
        const pushTokens = (request.recipient.deviceTokens || []).filter(Boolean);
        if (pushTokens.length === 0) {
          return {
            success: false,
            communicationId,
            channel: activeChannel,
            providerId: route.primaryProviderId,
            status: DeliveryStatus.FAILED,
            attemptsCount: 0,
            costEstimate: 0,
            latencyMs: 0,
            error: 'No active device tokens provided for push dispatch',
          };
        }
        payload = {
          deviceTokens: pushTokens,
          title: renderedSubject || 'DriveGo Alert',
          body: renderedBody || 'Important vehicle update',
          data: request.directContent?.data,
          priority: request.priority === CommunicationPriority.CRITICAL ? 'high' : 'normal',
        };
        break;

      case CommunicationChannel.VOICE:
        capability = 'VOICE_CALL';
        payload = {
          to: request.recipient.phone,
          twimlOrScript: renderedBody || 'This is an important voice notification from DriveGo.',
          isOtp: !!request.otpCode,
          otpCode: request.otpCode,
          idempotencyKey: request.idempotencyKey,
        };
        break;
    }

    // 6. Execute Dispatch through Integration Runtime Service
    let currentProviderId = route.primaryProviderId;
    let fallbackChainUsed = false;
    let attemptsCount = 1;

    try {
      const executionResult: any = await this.runtimeService.execute({
        category,
        capability,
        preferredProviderId: currentProviderId,
        tenantId: request.tenantId,
        vendorId: request.vendorId,
        branchId: request.branchId,
        payload,
        idempotencyKey: request.idempotencyKey,
      });

      const providerMessageId =
        executionResult?.providerMessageId ||
        executionResult?.messageId ||
        executionResult?.callSid ||
        `msg_${Date.now()}`;

      const res: CommunicationResponse = {
        success: true,
        communicationId,
        channel: activeChannel,
        providerId: currentProviderId,
        providerMessageId,
        status: DeliveryStatus.SENT,
        fallbackChainUsed,
        attemptsCount,
        costEstimate: route.estimatedCost,
        latencyMs: Date.now() - startTime,
        explanation: route.explanation,
      };

      this.persistMessage(request, res).catch(() => {});
      return res;
    } catch (primaryErr: any) {
      this.logger.warn(`[COMM_DISPATCHER] Primary provider [${currentProviderId}] failed: ${primaryErr?.message}`);

      // Evaluate Fallback Safety
      const safety = this.routingService.evaluateCommunicationFallbackSafety({
        providerId: currentProviderId,
        channel: activeChannel,
        errorClass: primaryErr?.classification || 'PROVIDER_DOWN',
        requestDispatchedToProvider: false,
        errorMessage: primaryErr?.message,
      });

      if (!safety.safeToFailover || route.fallbackChain.length === 0) {
        const failRes: CommunicationResponse = {
          success: false,
          communicationId,
          channel: activeChannel,
          providerId: currentProviderId,
          status: safety.recommendedStatus,
          fallbackChainUsed: false,
          attemptsCount,
          costEstimate: 0,
          latencyMs: Date.now() - startTime,
          explanation: safety.reason,
          error: primaryErr?.message,
        };
        this.persistMessage(request, failRes).catch(() => {});
        return failRes;
      }

      // Execute Fallback Candidate
      const fallbackTarget = route.fallbackChain[0];
      currentProviderId = fallbackTarget.providerId;
      fallbackChainUsed = true;
      attemptsCount++;

      this.logger.log(`[COMM_DISPATCHER] Executing fallback to provider [${currentProviderId}] on channel [${fallbackTarget.channel}]`);

      try {
        const fbCategory = this.routingService.mapChannelToCategory(fallbackTarget.channel);
        const fbResult: any = await this.runtimeService.execute({
          category: fbCategory,
          capability,
          preferredProviderId: currentProviderId,
          tenantId: request.tenantId,
          vendorId: request.vendorId,
          branchId: request.branchId,
          payload,
          idempotencyKey: request.idempotencyKey ? `${request.idempotencyKey}_fb` : undefined,
        });

        const providerMessageId =
          fbResult?.providerMessageId ||
          fbResult?.messageId ||
          fbResult?.callSid ||
          `fb_msg_${Date.now()}`;

        const fbSuccessRes: CommunicationResponse = {
          success: true,
          communicationId,
          channel: fallbackTarget.channel,
          providerId: currentProviderId,
          providerMessageId,
          status: DeliveryStatus.FALLBACK_SENT,
          fallbackChainUsed: true,
          attemptsCount,
          costEstimate: route.estimatedCost,
          latencyMs: Date.now() - startTime,
          explanation: `Fallback engaged after ${primaryErr?.message}. Delivered via ${currentProviderId}.`,
        };
        this.persistMessage(request, fbSuccessRes).catch(() => {});
        return fbSuccessRes;
      } catch (fbErr: any) {
        const fbFailRes: CommunicationResponse = {
          success: false,
          communicationId,
          channel: fallbackTarget.channel,
          providerId: currentProviderId,
          status: DeliveryStatus.FAILED,
          fallbackChainUsed: true,
          attemptsCount,
          costEstimate: 0,
          latencyMs: Date.now() - startTime,
          error: `Primary and fallback both failed: ${fbErr?.message}`,
        };
        this.persistMessage(request, fbFailRes).catch(() => {});
        return fbFailRes;
      }
    }
  }

  private async persistMessage(request: CommunicationRequest, res: CommunicationResponse): Promise<void> {
    if (!this.prisma?.communicationMessage) return;
    try {
      const recipient = request.recipient.phone || request.recipient.email || request.recipient.id || 'unknown';
      await this.prisma.communicationMessage.create({
        data: {
          id: res.communicationId,
          tenantId: request.tenantId || null,
          vendorId: request.vendorId || null,
          branchId: request.branchId || null,
          userId: request.recipient.id || null,
          recipient,
          channel: res.channel,
          messageType: request.messageType,
          priority: request.priority || 'NORMAL',
          status: res.status,
          templateName: request.template?.templateName || null,
          language: request.template?.language || request.recipient.language || 'en',
          providerId: res.providerId || null,
          providerMessageId: res.providerMessageId || null,
          idempotencyKey: request.idempotencyKey || null,
          correlationId: request.correlationId || null,
          cost: res.costEstimate ? (res.costEstimate as any) : null,
          attempts: res.attemptsCount || 1,
          lastError: res.error || null,
          deliveredAt: res.success ? new Date() : null,
          failedAt: !res.success ? new Date() : null,
          metadata: {
            fallbackUsed: res.fallbackChainUsed,
            explanation: res.explanation,
          },
        },
      });
    } catch (err: any) {
      this.logger.debug(`[COMM_DISPATCHER] Message persistence bypassed: ${err?.message}`);
    }
  }
}
