import { Injectable, Logger } from '@nestjs/common';
import { CircuitState, CircuitBreakerConfig, FailureClassification } from './runtime.types';
import { IntegrationCategory } from '../registry/provider.types';

export interface CircuitStatusRecord {
  category?: IntegrationCategory | string;
  providerId: string;
  state: CircuitState;
  failureCount: number;
  lastFailureTime?: Date | null;
  lastOpenedTime?: Date | null;
  openedReason?: string | null;
  cooldownRemainingMs: number;
}

interface InternalCircuitState {
  state: CircuitState;
  failureTimestamps: number[];
  openedAt?: number;
  halfOpenProbesCount: number;
  consecutiveSuccesses: number;
  openedReason?: string;
  config: CircuitBreakerConfig;
}

const DEFAULT_CONFIG: CircuitBreakerConfig = {
  failureThreshold: 5,
  rollingWindowMs: 60000,
  openDurationMs: 30000,
  halfOpenProbes: 3,
  successThreshold: 2,
  timeoutThresholdMs: 10000,
};

@Injectable()
export class CircuitBreakerService {
  private readonly logger = new Logger(CircuitBreakerService.name);
  private readonly circuits = new Map<string, InternalCircuitState>();
  private readonly providerConfigs = new Map<string, CircuitBreakerConfig>();

  private normalizeKey(arg1: string, arg2?: string): { key: string; providerId: string } {
    if (arg2) {
      return { key: `${arg1}:${arg2}`.toLowerCase(), providerId: arg2.toLowerCase() };
    }
    return { key: arg1.toLowerCase(), providerId: arg1.toLowerCase() };
  }

  private getOrCreate(arg1: string, arg2?: string): InternalCircuitState {
    const { key, providerId } = this.normalizeKey(arg1, arg2);
    let state = this.circuits.get(key);
    if (!state) {
      const cfg = this.providerConfigs.get(providerId) || { ...DEFAULT_CONFIG };
      state = {
        state: CircuitState.CLOSED,
        failureTimestamps: [],
        halfOpenProbesCount: 0,
        consecutiveSuccesses: 0,
        config: cfg,
      };
      this.circuits.set(key, state);
    }
    return state;
  }

  public setProviderConfig(
    providerId: string,
    config: Partial<CircuitBreakerConfig>,
  ): void {
    const current = this.providerConfigs.get(providerId.toLowerCase()) || {
      ...DEFAULT_CONFIG,
    };
    const updated = { ...current, ...config };
    this.providerConfigs.set(providerId.toLowerCase(), updated);

    const existing = this.circuits.get(providerId.toLowerCase());
    if (existing) {
      existing.config = updated;
    }
  }

  /**
   * Evaluates if a request to the provider is allowed to proceed.
   */
  canExecute(arg1: string, arg2?: string): boolean {
    const circuit = this.getOrCreate(arg1, arg2);
    const now = Date.now();

    if (circuit.state === CircuitState.CLOSED) {
      return true;
    }

    if (circuit.state === CircuitState.OPEN) {
      // Check if cooldown duration has elapsed
      if (circuit.openedAt && now - circuit.openedAt >= circuit.config.openDurationMs) {
        circuit.state = CircuitState.HALF_OPEN;
        circuit.halfOpenProbesCount = 1;
        circuit.consecutiveSuccesses = 0;
        this.logger.log(`[CIRCUIT_BREAKER] Circuit for ${arg2 || arg1} entering HALF_OPEN trial state`);
        return true;
      }
      return false; // Still OPEN
    }

    if (circuit.state === CircuitState.HALF_OPEN) {
      if (circuit.halfOpenProbesCount < circuit.config.halfOpenProbes) {
        circuit.halfOpenProbesCount++;
        return true;
      }
      return false; // Max probes in flight
    }

    return true;
  }

  /**
   * Records a successful execution.
   */
  recordSuccess(arg1: string, arg2?: string): CircuitState {
    const circuit = this.getOrCreate(arg1, arg2);

    if (circuit.state === CircuitState.HALF_OPEN) {
      circuit.consecutiveSuccesses++;
      if (circuit.consecutiveSuccesses >= circuit.config.successThreshold) {
        circuit.state = CircuitState.CLOSED;
        circuit.failureTimestamps = [];
        circuit.openedAt = undefined;
        circuit.openedReason = undefined;
        circuit.halfOpenProbesCount = 0;
        circuit.consecutiveSuccesses = 0;
        this.logger.log(`[CIRCUIT_BREAKER] Circuit for ${arg2 || arg1} recovered -> CLOSED`);
      }
    } else if (circuit.state === CircuitState.CLOSED) {
      circuit.failureTimestamps = [];
    }

    return circuit.state;
  }

  /**
   * Records a failed execution and returns current state.
   */
  recordFailure(
    arg1: string,
    arg2OrClassification?: any,
    classificationOrReason?: any,
    reason?: string,
  ): CircuitState {
    let circuit: InternalCircuitState;
    let classification: FailureClassification | undefined;
    let actualReason: string | undefined;

    if (typeof arg2OrClassification === 'string' && Object.values(IntegrationCategory).includes(arg1 as any)) {
      // Called as recordFailure(category, providerId, classification, reason)
      circuit = this.getOrCreate(arg1, arg2OrClassification);
      classification = classificationOrReason;
      actualReason = reason;
    } else {
      // Called as recordFailure(providerId, classification, reason)
      circuit = this.getOrCreate(arg1);
      classification = arg2OrClassification;
      actualReason = classificationOrReason;
    }

    const now = Date.now();

    if (circuit.state === CircuitState.HALF_OPEN) {
      circuit.state = CircuitState.OPEN;
      circuit.openedAt = now;
      circuit.openedReason = actualReason || `Probe failed with ${classification || 'error'}`;
      circuit.halfOpenProbesCount = 0;
      circuit.consecutiveSuccesses = 0;
      this.logger.warn(`[CIRCUIT_BREAKER] Probe failed for ${arg1} -> Tripped back to OPEN`);
      return circuit.state;
    }

    if (circuit.state === CircuitState.CLOSED) {
      circuit.failureTimestamps.push(now);

      // Evict failures outside rolling window
      circuit.failureTimestamps = circuit.failureTimestamps.filter(
        (ts) => now - ts <= circuit.config.rollingWindowMs,
      );

      if (circuit.failureTimestamps.length >= circuit.config.failureThreshold) {
        circuit.state = CircuitState.OPEN;
        circuit.openedAt = now;
        circuit.openedReason =
          actualReason ||
          `Exceeded ${circuit.config.failureThreshold} failures within ${circuit.config.rollingWindowMs / 1000}s`;
        this.logger.error(`[CIRCUIT_BREAKER] TRIP to OPEN for ${arg1}: ${circuit.openedReason}`);
      }
    }

    return circuit.state;
  }

  getState(arg1: string, arg2?: string): CircuitState {
    const circuit = this.getOrCreate(arg1, arg2);
    const now = Date.now();

    // Check if OPEN cooldown has elapsed
    if (circuit.state === CircuitState.OPEN && circuit.openedAt) {
      if (now - circuit.openedAt >= circuit.config.openDurationMs) {
        circuit.state = CircuitState.HALF_OPEN;
        circuit.halfOpenProbesCount = 0;
        circuit.consecutiveSuccesses = 0;
      }
    }

    return circuit.state;
  }

  getAllStates(): Record<string, CircuitState> {
    const res: Record<string, CircuitState> = {};
    for (const [key] of this.circuits.entries()) {
      res[key] = this.getState(key);
    }
    return res;
  }

  resetCircuit(arg1: string, arg2?: string): void {
    const circuit = this.getOrCreate(arg1, arg2);
    circuit.state = CircuitState.CLOSED;
    circuit.failureTimestamps = [];
    circuit.openedAt = undefined;
    circuit.openedReason = undefined;
    circuit.halfOpenProbesCount = 0;
    circuit.consecutiveSuccesses = 0;
  }

  tripCircuit(arg1: string, arg2OrReason?: string, reason?: string): void {
    let circuit: InternalCircuitState;
    let actualReason: string | undefined;

    if (arg2OrReason && Object.values(IntegrationCategory).includes(arg1 as any)) {
      circuit = this.getOrCreate(arg1, arg2OrReason);
      actualReason = reason;
    } else {
      circuit = this.getOrCreate(arg1);
      actualReason = arg2OrReason;
    }

    circuit.state = CircuitState.OPEN;
    circuit.openedAt = Date.now();
    circuit.openedReason = actualReason || 'Manually tripped by Admin';
    circuit.halfOpenProbesCount = 0;
    circuit.consecutiveSuccesses = 0;
  }

  resetAll(): void {
    for (const circuit of this.circuits.values()) {
      circuit.state = CircuitState.CLOSED;
      circuit.failureTimestamps = [];
      circuit.openedAt = undefined;
      circuit.openedReason = undefined;
      circuit.halfOpenProbesCount = 0;
      circuit.consecutiveSuccesses = 0;
    }
  }

  getCircuitStatus(arg1: string, arg2?: string): CircuitStatusRecord {
    const circuit = this.getOrCreate(arg1, arg2);
    const { key, providerId } = this.normalizeKey(arg1, arg2);
    const now = Date.now();
    let cooldownRemainingMs = 0;

    if (circuit.state === CircuitState.OPEN && circuit.openedAt) {
      const elapsed = now - circuit.openedAt;
      cooldownRemainingMs = Math.max(0, circuit.config.openDurationMs - elapsed);
    }

    const lastTs =
      circuit.failureTimestamps.length > 0
        ? circuit.failureTimestamps[circuit.failureTimestamps.length - 1]
        : null;

    return {
      category: arg2 ? arg1 : undefined,
      providerId,
      state: circuit.state,
      failureCount: circuit.failureTimestamps.length,
      lastFailureTime: lastTs ? new Date(lastTs) : null,
      lastOpenedTime: circuit.openedAt ? new Date(circuit.openedAt) : null,
      openedReason: circuit.openedReason,
      cooldownRemainingMs,
    };
  }

  getAllCircuitStatuses(): CircuitStatusRecord[] {
    const results: CircuitStatusRecord[] = [];
    for (const key of this.circuits.keys()) {
      results.push(this.getCircuitStatus(key));
    }
    return results;
  }
}
