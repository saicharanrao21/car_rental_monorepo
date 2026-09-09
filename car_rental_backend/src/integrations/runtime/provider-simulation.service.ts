import { Injectable, Logger } from '@nestjs/common';
import { SimulationScenario } from './runtime.types';

@Injectable()
export class ProviderSimulationService {
  private readonly logger = new Logger(ProviderSimulationService.name);
  private readonly providerScenarios = new Map<string, SimulationScenario>();

  public setProviderSimulation(providerId: string, scenario: SimulationScenario): void {
    if (scenario === SimulationScenario.NONE) {
      this.providerScenarios.delete(providerId);
    } else {
      this.providerScenarios.set(providerId, scenario);
      this.logger.warn(`Provider simulation set for ${providerId}: ${scenario}`);
    }
  }

  public getProviderSimulation(providerId: string): SimulationScenario {
    return this.providerScenarios.get(providerId) || SimulationScenario.NONE;
  }

  public clearProviderSimulation(providerId: string): void {
    this.providerScenarios.delete(providerId);
  }

  public clearAllSimulations(): void {
    this.providerScenarios.clear();
  }

  public shouldSimulate(providerId: string, requestScenario?: SimulationScenario): boolean {
    if (requestScenario && requestScenario !== SimulationScenario.NONE) {
      return true;
    }
    const registered = this.providerScenarios.get(providerId);
    return !!registered && registered !== SimulationScenario.NONE;
  }

  public resolveScenario(providerId: string, requestScenario?: SimulationScenario): SimulationScenario {
    if (requestScenario && requestScenario !== SimulationScenario.NONE) {
      return requestScenario;
    }
    return this.providerScenarios.get(providerId) || SimulationScenario.NONE;
  }

  public async simulateExecution<TOutput = any>(
    providerId: string,
    capability: string,
    scenario: SimulationScenario,
    payload: any,
  ): Promise<TOutput> {
    // Safety check: Prevent simulation in LIVE production environment
    if (payload?.environment === 'LIVE' || payload?.isProduction === true) {
      throw new Error(
        `[SIMULATION_SAFETY] Sandbox simulation cannot execute against LIVE production credentials for provider ${providerId}`,
      );
    }

    this.logger.log(`Simulating execution for provider=${providerId}, capability=${capability}, scenario=${scenario}`);

    switch (scenario) {
      case SimulationScenario.SUCCESS: {
        await new Promise((resolve) => setTimeout(resolve, 10));
        return {
          simulated: true,
          providerId,
          capability,
          status: 'SUCCESS',
          referenceId: `sim_${providerId}_${Date.now()}`,
          timestamp: new Date().toISOString(),
          echo: payload,
        } as unknown as TOutput;
      }

      case SimulationScenario.TIMEOUT: {
        await new Promise((resolve) => setTimeout(resolve, 50));
        const err: any = new Error(`Provider ${providerId} timed out after 5000ms`);
        err.code = 'ETIMEDOUT';
        err.status = 504;
        throw err;
      }

      case SimulationScenario.NETWORK_FAILURE: {
        const err: any = new Error(`ECONNREFUSED: Connection refused by upstream ${providerId}`);
        err.code = 'ECONNREFUSED';
        throw err;
      }

      case SimulationScenario.AUTH_FAILURE: {
        const err: any = new Error(`401 Unauthorized: Invalid API key for provider ${providerId}`);
        err.status = 401;
        err.response = { status: 401, data: { error: 'Authentication failed' } };
        throw err;
      }

      case SimulationScenario.RATE_LIMIT: {
        const err: any = new Error(`429 Too Many Requests: Rate limit exceeded for ${providerId}`);
        err.status = 429;
        err.response = {
          status: 429,
          headers: { 'retry-after': '2' },
          data: { error: 'Quota exceeded' },
        };
        throw err;
      }

      case SimulationScenario.PROVIDER_DECLINED: {
        const err: any = new Error(`402 Payment Required: Card was declined by bank via ${providerId}`);
        err.status = 402;
        err.response = { status: 402, data: { declineCode: 'insufficient_funds' } };
        throw err;
      }

      case SimulationScenario.SLOW_RESPONSE: {
        await new Promise((resolve) => setTimeout(resolve, 80));
        return {
          simulated: true,
          providerId,
          capability,
          status: 'SUCCESS',
          latency: 'SLOW',
          referenceId: `sim_slow_${providerId}_${Date.now()}`,
        } as unknown as TOutput;
      }

      case SimulationScenario.MALFORMED_RESPONSE: {
        const err: any = new Error(`SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON`);
        err.code = 'MALFORMED_RESPONSE';
        throw err;
      }

      case SimulationScenario.INVALID_REQUEST: {
        const err: any = new Error(`400 Bad Request: Invalid request parameters supplied to ${providerId}`);
        err.status = 400;
        err.code = 'INVALID_REQUEST';
        err.response = { status: 400, data: { error: 'Invalid payload structure' } };
        throw err;
      }

      case SimulationScenario.DUPLICATE: {
        const err: any = new Error(`409 Conflict: Duplicate transaction detected on provider ${providerId}`);
        err.status = 409;
        err.code = 'DUPLICATE_TRANSACTION';
        err.response = { status: 409, data: { error: 'Duplicate transaction' } };
        throw err;
      }

      case SimulationScenario.NOT_SUPPORTED: {
        const err: any = new Error(`501 Not Implemented: Capability '${capability}' is not supported by ${providerId}`);
        err.status = 501;
        err.code = 'NOT_SUPPORTED';
        throw err;
      }

      case SimulationScenario.CONFIGURATION_FAILURE: {
        const err: any = new Error(`Configuration Error: Missing credentials or webhook secret for provider ${providerId}`);
        err.code = 'CONFIGURATION_ERROR';
        throw err;
      }

      case SimulationScenario.AUTH_401: {
        const err: any = new Error(`401 Unauthorized: Invalid API key or token expired for provider ${providerId}`);
        err.status = 401;
        err.response = { status: 401, data: { error: 'Authentication failed' } };
        throw err;
      }

      case SimulationScenario.FORBIDDEN_403: {
        const err: any = new Error(`403 Forbidden: Insufficient permissions for capability '${capability}' on ${providerId}`);
        err.status = 403;
        err.response = { status: 403, data: { error: 'Access forbidden' } };
        throw err;
      }

      case SimulationScenario.RATE_LIMIT_429: {
        const err: any = new Error(`429 Too Many Requests: Rate limit exceeded for ${providerId}`);
        err.status = 429;
        err.response = { status: 429, headers: { 'retry-after': '3' }, data: { error: 'Quota exceeded' } };
        throw err;
      }

      case SimulationScenario.WEBHOOK_SIGNATURE_MISMATCH: {
        const err: any = new Error(`Webhook Signature Error: Signature mismatch on provider ${providerId}`);
        err.code = 'SIGNATURE_MISMATCH';
        err.status = 400;
        throw err;
      }

      case SimulationScenario.LATENCY_INJECTION: {
        await new Promise((resolve) => setTimeout(resolve, 200));
        return {
          simulated: true,
          providerId,
          capability,
          status: 'SUCCESS',
          latencyInjectedMs: 200,
          referenceId: `sim_lat_${providerId}_${Date.now()}`,
        } as unknown as TOutput;
      }

      case SimulationScenario.PARTIAL_FAILURE: {
        const err: any = new Error(`Partial Failure: Primary action completed but webhook notification failed on ${providerId}`);
        err.code = 'PARTIAL_FAILURE';
        err.status = 207;
        throw err;
      }

      case SimulationScenario.WEBHOOK_FAILURE: {
        const err: any = new Error(`Webhook Delivery Error: HMAC signature verification failed for ${providerId}`);
        err.code = 'WEBHOOK_VERIFICATION_FAILED';
        throw err;
      }

      default:
        throw new Error(`Unsupported simulation scenario: ${scenario}`);
    }
  }
}
