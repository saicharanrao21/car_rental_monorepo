import { Injectable, Logger } from '@nestjs/common';
import { ProviderRegistryService } from '../registry/provider-registry.service';
import { ProviderCatalogService } from '../catalog/provider-catalog.service';
import { ProviderRoutingService } from './provider-routing.service';
import { CircuitBreakerService } from './circuit-breaker.service';
import { ProviderRateLimiterService } from './provider-rate-limiter.service';
import { FailureClassifierService } from './failure-classifier.service';
import { IntegrationIdempotencyService } from './integration-idempotency.service';
import { ProviderSimulationService } from './provider-simulation.service';
import { ProviderHealthService } from '../health/provider-health.service';
import { IntegrationAuditService } from './integration-audit.service';
import {
  CircuitState,
  FailureClassification,
  IntegrationAttemptRecord,
  IntegrationExecutionRequest,
  IntegrationExecutionResult,
} from './runtime.types';
import { ProviderEnvironment } from '../catalog/provider-catalog.types';
import { IntegrationCategory } from '../registry/provider.types';
import { BaseProvider } from '../contracts/provider.interface';

@Injectable()
export class IntegrationRuntimeService {
  private readonly logger = new Logger(IntegrationRuntimeService.name);

  constructor(
    private readonly registryService: ProviderRegistryService,
    private readonly catalogService: ProviderCatalogService,
    private readonly routingService: ProviderRoutingService,
    private readonly circuitBreakerService: CircuitBreakerService,
    private readonly rateLimiter: ProviderRateLimiterService,
    private readonly failureClassifier: FailureClassifierService,
    private readonly idempotencyService: IntegrationIdempotencyService,
    private readonly simulationService: ProviderSimulationService,
    private readonly healthService: ProviderHealthService,
    private readonly auditService: IntegrationAuditService,
  ) {}

  /**
   * Central entry point for executing any integration capability across any category.
   * Handles capability negotiation, intelligent routing, circuit breaking, rate limiting,
   * safe retries, fallbacks, idempotency deduplication, and structured telemetry.
   */
  public async execute<TInput = any, TOutput = any>(
    request: IntegrationExecutionRequest<TInput>,
  ): Promise<IntegrationExecutionResult<TOutput>> {
    const startTime = Date.now();
    const correlationId =
      request.metadata?.correlationId ||
      `cor_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // 1. Idempotency check: return cached response if already completed
    if (request.idempotencyKey) {
      const cached = await this.idempotencyService.checkIdempotency<TOutput>(
        request.idempotencyKey,
      );
      if (cached) {
        this.logger.log(
          `[IDEMPOTENCY_HIT] Returning cached execution for key: ${request.idempotencyKey}`,
        );
        return {
          success: true,
          data: cached,
          providerId: 'cached_idempotency',
          category: request.category,
          capability: request.capability,
          environment: request.environment || ProviderEnvironment.SANDBOX,
          attempts: [],
          fallbackOccurred: false,
          latencyMs: Date.now() - startTime,
          correlationId,
          idempotencyKey: request.idempotencyKey,
        };
      }
    }

    // 2. Resolve candidates (primary + fallback chain) via ProviderRoutingEngine
    let routingResolution;
    try {
      routingResolution = await this.routingService.resolveRoutingChain(request);
    } catch (err: any) {
      const latencyMs = Date.now() - startTime;
      const failureResult: IntegrationExecutionResult<TOutput> = {
        success: false,
        error: {
          code: 'ROUTING_FAILED',
          message: err.message,
          classification: FailureClassification.CONFIGURATION,
          providerId: 'none',
        },
        providerId: 'none',
        category: request.category,
        capability: request.capability,
        environment: request.environment || ProviderEnvironment.SANDBOX,
        attempts: [],
        fallbackOccurred: false,
        latencyMs,
        correlationId,
        idempotencyKey: request.idempotencyKey,
      };
      await this.auditService.recordExecution(request, failureResult);
      return failureResult;
    }

    const { primaryProviderId, fallbackChain, allCandidates, explanation } =
      routingResolution;
    const candidatesToTry = [primaryProviderId, ...fallbackChain];
    const attempts: IntegrationAttemptRecord[] = [];
    let fallbackOccurred = false;
    let finalSuccessfulResult: TOutput | undefined;
    let finalProviderUsed = primaryProviderId;
    let finalError: any = null;

    // 3. Fallback execution loop
    for (let cIdx = 0; cIdx < candidatesToTry.length; cIdx++) {
      const currentProviderId = candidatesToTry[cIdx];
      if (cIdx > 0) {
        fallbackOccurred = true;
        this.logger.warn(
          `[FAILOVER_ENGAGED] Attempting fallback provider ${currentProviderId} (attempt ${cIdx + 1}/${candidatesToTry.length}) for ${request.category}/${request.capability}`,
        );
      }

      // Check Circuit Breaker
      const canExecCircuit = this.circuitBreakerService.canExecute(currentProviderId);
      if (!canExecCircuit) {
        this.logger.warn(
          `[CIRCUIT_BYPASS] Provider ${currentProviderId} circuit is OPEN. Bypassing to fallback.`,
        );
        attempts.push({
          attemptNumber: attempts.length + 1,
          providerId: currentProviderId,
          status: 'CIRCUIT_OPEN',
          errorClassification: FailureClassification.TRANSIENT,
          errorMessage: `Circuit breaker is OPEN for provider ${currentProviderId}`,
          latencyMs: 0,
          timestamp: new Date(),
        });
        continue;
      }

      // Check Rate Limiting
      const allowedRate = this.rateLimiter.isAllowed(
        currentProviderId,
        request.vendorId,
        request.capability,
      );
      if (!allowedRate) {
        this.logger.warn(
          `[RATE_LIMIT_BYPASS] Provider ${currentProviderId} rate limit exceeded. Bypassing to fallback.`,
        );
        attempts.push({
          attemptNumber: attempts.length + 1,
          providerId: currentProviderId,
          status: 'RATE_LIMITED',
          errorClassification: FailureClassification.RATE_LIMITED,
          errorMessage: `Rate limit quota exceeded for provider ${currentProviderId}`,
          latencyMs: 0,
          timestamp: new Date(),
        });
        continue;
      }

      // Acquire concurrency slot
      const concurrencyAcquired = this.rateLimiter.acquireConcurrency(currentProviderId);
      if (!concurrencyAcquired) {
        this.logger.warn(
          `[CONCURRENCY_EXHAUSTED] Provider ${currentProviderId} concurrency limit reached. Bypassing.`,
        );
        attempts.push({
          attemptNumber: attempts.length + 1,
          providerId: currentProviderId,
          status: 'RATE_LIMITED',
          errorClassification: FailureClassification.RATE_LIMITED,
          errorMessage: `Max concurrency limit reached for ${currentProviderId}`,
          latencyMs: 0,
          timestamp: new Date(),
        });
        continue;
      }

      // Retry loop for the current provider
      const maxRetriesOnProvider = 2; // Up to 2 retries (total 3 attempts on this provider)
      let providerSuccess = false;

      try {
        for (let retryIdx = 0; retryIdx <= maxRetriesOnProvider; retryIdx++) {
          const attemptStart = Date.now();
          const attemptNumber = attempts.length + 1;

          try {
            // Execution (Simulation or Real Provider)
            let rawResult: TOutput;
            if (this.simulationService.shouldSimulate(currentProviderId, request.simulationScenario)) {
              const scenario = this.simulationService.resolveScenario(
                currentProviderId,
                request.simulationScenario,
              );
              rawResult = await this.simulationService.simulateExecution<TOutput>(
                currentProviderId,
                request.capability,
                scenario,
                request.payload,
              );
            } else {
              rawResult = await this.invokeLiveProvider<TInput, TOutput>(
                request.category,
                currentProviderId,
                request.capability,
                request.payload,
                request.timeoutMs,
              );
            }

            const attemptLatency = Date.now() - attemptStart;
            attempts.push({
              attemptNumber,
              providerId: currentProviderId,
              status: 'SUCCESS',
              latencyMs: attemptLatency,
              timestamp: new Date(),
            });

            // Record success telemetry
            this.circuitBreakerService.recordSuccess(currentProviderId);
            this.healthService.recordExecutionOutcome(request.category, currentProviderId, {
              success: true,
              latencyMs: attemptLatency,
            });

            finalSuccessfulResult = rawResult;
            finalProviderUsed = currentProviderId;
            providerSuccess = true;
            break; // Break out of retry loop
          } catch (err: any) {
            const attemptLatency = Date.now() - attemptStart;
            const classification = this.failureClassifier.classify(err);

            // Record circuit & health failure
            const circuitStateNow = this.circuitBreakerService.recordFailure(
              currentProviderId,
              classification,
            );
            this.healthService.recordExecutionOutcome(request.category, currentProviderId, {
              success: false,
              latencyMs: attemptLatency,
              classification,
            });

            if (circuitStateNow === CircuitState.OPEN) {
              await this.auditService.recordIncident({
                providerId: currentProviderId,
                category: request.category,
                title: `Provider ${currentProviderId} circuit opened`,
                severity: 'HIGH',
                circuitState: CircuitState.OPEN,
                reason: err.message,
              });
            }

            const attemptStatus =
              classification === FailureClassification.TIMEOUT
                ? 'TIMEOUT'
                : classification === FailureClassification.RATE_LIMITED
                ? 'RATE_LIMITED'
                : 'FAILED';

            attempts.push({
              attemptNumber,
              providerId: currentProviderId,
              status: attemptStatus,
              errorClassification: classification,
              errorMessage: err.message || 'Execution error',
              latencyMs: attemptLatency,
              timestamp: new Date(),
            });

            finalError = {
              code: err.code || 'PROVIDER_ERROR',
              message: err.message || 'Execution failed on provider',
              classification,
              providerId: currentProviderId,
              details: err.response?.data || err.details,
            };

            // Safe Retry Decision:
            // 1. Must be a retryable failure classification
            // 2. Safe idempotency rule: NEVER blindly retry non-idempotent operations without key
            const isSafeToRetry =
              this.failureClassifier.isRetryable(classification) &&
              (request.isIdempotent === true || !!request.idempotencyKey) &&
              retryIdx < maxRetriesOnProvider;

            if (isSafeToRetry) {
              const backoff = this.failureClassifier.calculateBackoff(retryIdx, err);
              this.logger.log(
                `[RETRY_SCHEDULED] Retrying ${currentProviderId} in ${backoff}ms (attempt ${retryIdx + 2}/${maxRetriesOnProvider + 1})`,
              );
              await new Promise((res) => setTimeout(res, backoff));
              continue; // Retry loop
            }

            // If not safe to retry or retries exhausted, check if fallback is allowed
            const fallbackEligible = this.failureClassifier.isFallbackEligible(classification);
            if (!fallbackEligible) {
              // Non-fallback-eligible errors (e.g. invalid request parameters) should NOT failover
              this.logger.warn(
                `[FAILOVER_ABORTED] Error classification ${classification} is not eligible for fallback. Aborting.`,
              );
              break;
            }

            // Break out of retry loop to move to next candidate provider
            break;
          }
        }
      } finally {
        this.rateLimiter.releaseConcurrency(currentProviderId);
      }

      if (providerSuccess) {
        break; // Successfully completed via current provider, stop fallback chain
      }
    }

    const totalLatencyMs = Date.now() - startTime;
    const environment = request.environment || ProviderEnvironment.SANDBOX;

    // 4. Construct final result
    if (finalSuccessfulResult !== undefined) {
      const successResult: IntegrationExecutionResult<TOutput> = {
        success: true,
        data: finalSuccessfulResult,
        providerId: finalProviderUsed,
        category: request.category,
        capability: request.capability,
        environment,
        attempts,
        fallbackOccurred,
        latencyMs: totalLatencyMs,
        correlationId,
        idempotencyKey: request.idempotencyKey,
        explanation,
      };

      // Persist idempotency result if key provided
      if (request.idempotencyKey) {
        await this.idempotencyService.recordSuccess(
          request.idempotencyKey,
          finalSuccessfulResult,
        );
      }

      await this.auditService.recordExecution(request, successResult);
      return successResult;
    } else {
      const failureResult: IntegrationExecutionResult<TOutput> = {
        success: false,
        error: finalError || {
          code: 'ALL_PROVIDERS_FAILED',
          message: 'All configured providers in fallback chain failed execution',
          classification: FailureClassification.PERMANENT,
          providerId: finalProviderUsed,
        },
        providerId: finalProviderUsed,
        category: request.category,
        capability: request.capability,
        environment,
        attempts,
        fallbackOccurred,
        latencyMs: totalLatencyMs,
        correlationId,
        idempotencyKey: request.idempotencyKey,
        explanation,
      };

      await this.auditService.recordExecution(request, failureResult);
      return failureResult;
    }
  }

  /**
   * Invokes live provider adapter dynamically based on capability.
   */
  private async invokeLiveProvider<TInput, TOutput>(
    category: IntegrationCategory,
    providerId: string,
    capability: string,
    payload: TInput,
    customTimeoutMs?: number,
  ): Promise<TOutput> {
    const provider = await this.registryService.getProvider<BaseProvider>(
      category,
      providerId,
    );

    const timeoutMs = customTimeoutMs || provider.getDefaultTimeoutMs?.() || 10000;

    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => {
        const err: any = new Error(`Provider ${providerId} timed out after ${timeoutMs}ms`);
        err.code = 'ETIMEDOUT';
        err.status = 504;
        reject(err);
      }, timeoutMs);
    });

    const executionPromise = (async () => {
      const pAny = provider as any;
      const capUpper = capability.toUpperCase();

      // Direct capability executor
      if (typeof pAny.executeCapability === 'function') {
        return await pAny.executeCapability(capability, payload);
      }

      // Payments
      if (category === IntegrationCategory.PAYMENT) {
        if (capUpper === 'CREATE_ORDER' || capUpper === 'CREATE_PAYMENT') {
          return await pAny.createOrder(payload);
        }
        if (capUpper === 'VERIFY_PAYMENT') {
          return await pAny.verifyPayment(payload);
        }
        if (capUpper === 'REFUND_PAYMENT' || capUpper === 'REFUND') {
          return await pAny.refund(payload);
        }
        if (capUpper === 'CAPTURE_PAYMENT') {
          return pAny.capturePayment ? await pAny.capturePayment(payload) : await pAny.verifyPayment(payload);
        }
      }

      // Messaging / WhatsApp / SMS / Email / Push
      if (capUpper === 'SEND_TEMPLATE' || capUpper === 'SEND_WHATSAPP') {
        return await pAny.sendTemplateMessage(payload);
      }
      if (capUpper === 'SEND_SMS' || capUpper === 'SEND_TRANSACTIONAL' || capUpper === 'SEND_OTP') {
        return await pAny.sendSms(payload);
      }
      if (capUpper === 'SEND_EMAIL') {
        return await pAny.sendEmail(payload);
      }
      if (capUpper === 'SEND_PUSH') {
        return await pAny.sendPush(payload);
      }
      if (capUpper === 'VOICE_CALL' || capUpper === 'VOICE_OTP') {
        return await pAny.initiateVoiceCall(payload);
      }

      // Storage
      if (capUpper === 'UPLOAD' || capUpper === 'UPLOAD_MEDIA') {
        return await pAny.uploadFile(payload);
      }
      if (capUpper === 'DELETE_FILE') {
        return await pAny.deleteFile(payload);
      }
      if (capUpper === 'GET_SIGNED_URL') {
        return await pAny.getSignedUrl(payload);
      }

      // Maps & Navigation
      if (capUpper === 'GEOCODE') {
        return await (pAny.geocode ? pAny.geocode(typeof payload === 'string' ? payload : (payload as any).address) : pAny.executeCapability(capability, payload));
      }
      if (capUpper === 'REVERSE_GEOCODE') {
        return await (pAny.reverseGeocode ? pAny.reverseGeocode(payload) : pAny.executeCapability(capability, payload));
      }
      if (capUpper === 'ROUTE' || capUpper === 'DIRECTIONS') {
        if (pAny.getDirections) {
          const origin = (payload as any).origin;
          const destination = (payload as any).destination;
          return await pAny.getDirections(origin, destination);
        }
      }
      if (capUpper === 'DISTANCE_MATRIX') {
        if (pAny.calculateDistanceMatrix) {
          return await pAny.calculateDistanceMatrix((payload as any).origins, (payload as any).destinations);
        }
        if (pAny.getDistanceMatrix) {
          return await pAny.getDistanceMatrix(payload);
        }
      }

      // Identity & Verification
      if (capUpper === 'VERIFY_IDENTITY' || capUpper === 'VERIFY_DOCUMENT') {
        return pAny.verifyIdentity ? await pAny.verifyIdentity(payload) : await pAny.verifyDocument(payload);
      }
      if (capUpper === 'PAN_VERIFY' || capUpper === 'PAN_VERIFICATION') {
        return pAny.verifyPan ? await pAny.verifyPan(payload) : await pAny.verifyIdentity(payload);
      }
      if (capUpper === 'AADHAAR_VERIFY' || capUpper === 'AADHAAR_VERIFICATION') {
        return pAny.verifyAadhaar ? await pAny.verifyAadhaar(payload) : await pAny.verifyIdentity(payload);
      }
      if (capUpper === 'DRIVING_LICENCE_VERIFY' || capUpper === 'DRIVING_LICENCE_VERIFICATION') {
        return await pAny.verifyDrivingLicence(payload);
      }
      if (capUpper === 'VEHICLE_RC_VERIFY' || capUpper === 'VEHICLE_RC_VERIFICATION') {
        return await pAny.verifyVehicleRc(payload);
      }
      if (capUpper === 'FACE_MATCH' || capUpper === 'LIVENESS') {
        return await pAny.verifyFaceMatch(payload);
      }

      // Vehicle Tracking & Telematics
      if (capUpper === 'GET_LOCATION' || capUpper === 'TRACK_VEHICLE' || capUpper === 'GPS_POSITION' || capUpper === 'LIVE_LOCATION') {
        if (pAny.getTelemetry) {
          return await pAny.getTelemetry(typeof payload === 'string' ? payload : (payload as any).vehicleId);
        }
        return await pAny.getCurrentLocation(payload);
      }
      if (capUpper === 'IMMOBILIZE') {
        const vId = typeof payload === 'string' ? payload : (payload as any).vehicleId || (payload as any).deviceId;
        const reason = (payload as any)?.reason || 'Operational security policy';
        return await pAny.immobilizeVehicle(vId, reason);
      }
      if (capUpper === 'RESTORE_ENGINE' || capUpper === 'UNIMMOBILIZE') {
        const vId = typeof payload === 'string' ? payload : (payload as any).vehicleId || (payload as any).deviceId;
        return await pAny.unimmobilizeVehicle(vId);
      }

      // Accounting & ERP
      if (capUpper === 'CREATE_INVOICE') {
        return pAny.createInvoice ? await pAny.createInvoice(payload) : await pAny.syncInvoice(payload);
      }
      if (capUpper === 'SYNC_INVOICE') {
        return await pAny.syncInvoice(payload);
      }
      if (capUpper === 'SYNC_PAYOUT') {
        return await pAny.syncPayout(payload);
      }
      if (capUpper === 'TAX_CALCULATION') {
        return await pAny.calculateTax(payload);
      }

      // AI & LLM
      if (capUpper === 'CHAT') {
        return await pAny.chat(payload);
      }
      if (capUpper === 'TEXT_GENERATION' || capUpper === 'GENERATE') {
        return await pAny.generateText(payload);
      }
      if (capUpper === 'SUMMARIZATION' || capUpper === 'SUMMARIZE') {
        return await pAny.summarize(payload);
      }
      if (capUpper === 'CLASSIFICATION' || capUpper === 'CLASSIFY') {
        return await pAny.classify(payload);
      }
      if (capUpper === 'EXTRACTION' || capUpper === 'EXTRACT') {
        return await pAny.extract(payload);
      }
      if (capUpper === 'EMBEDDINGS' || capUpper === 'EMBED') {
        return await pAny.embed(payload);
      }

      // Search
      if (capUpper === 'INDEX_DOCUMENT' || capUpper === 'BATCH_INDEX') {
        return await pAny.indexDocuments(payload);
      }
      if (capUpper === 'SEARCH_QUERY' || capUpper === 'SEARCH') {
        return await pAny.search(payload);
      }
      if (capUpper === 'DELETE_DOCUMENT') {
        return await pAny.deleteDocument((payload as any).indexName, (payload as any).documentId);
      }

      // Analytics
      if (capUpper === 'TRACK_EVENT' || capUpper === 'TRACK') {
        return await pAny.track(payload);
      }
      if (capUpper === 'IDENTIFY_USER' || capUpper === 'IDENTIFY') {
        return await pAny.identify(payload);
      }
      if (capUpper === 'BATCH_EVENTS') {
        return await pAny.batch(payload);
      }

      // Generic method match
      const camelCaseMethod = capability.charAt(0).toLowerCase() + capability.slice(1);
      if (typeof pAny[camelCaseMethod] === 'function') {
        return await pAny[camelCaseMethod](payload);
      }

      if (typeof pAny.execute === 'function') {
        return await pAny.execute(capability, payload);
      }

      throw new Error(
        `Capability '${capability}' is not executable on provider '${providerId}'`,
      );
    })();

    return (await Promise.race([executionPromise, timeoutPromise])) as TOutput;
  }

  /**
   * Enterprise Capability Invocation helper: Allows callers to request business capabilities
   * directly without vendor coupling, handling automatic unpacking of result data.
   */
  public async executeCapability<TOutput = any>(request: {
    category: IntegrationCategory;
    capability: string;
    parameters?: any;
    payload?: any;
    tenantId?: string;
    vendorId?: string;
    branchId?: string;
  }): Promise<TOutput> {
    const res = await this.execute<any, TOutput>({
      category: request.category,
      capability: request.capability,
      payload: request.payload !== undefined ? request.payload : request.parameters,
      tenantId: request.tenantId,
      vendorId: request.vendorId,
      branchId: request.branchId,
    });
    return res.data as TOutput;
  }
}
