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

      default:
        throw new Error(`Unsupported simulation scenario: ${scenario}`);
    }
  }
}
