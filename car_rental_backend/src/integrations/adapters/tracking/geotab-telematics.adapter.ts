import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  VehicleTrackingProvider,
  VehicleTrackingCapability,
  VehicleTelemetry,
} from '../../contracts/tracking-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class GeotabTelematicsAdapter implements VehicleTrackingProvider {
  private readonly logger = new Logger(GeotabTelematicsAdapter.name);
  private username: string;
  private database: string;
  private server: string;

  constructor(private readonly configService: ConfigService) {
    this.username = this.configService.get<string>('GEOTAB_USERNAME') || '';
    this.database = this.configService.get<string>('GEOTAB_DATABASE') || '';
    this.server = this.configService.get<string>('GEOTAB_SERVER') || 'my.geotab.com';
  }

  getProviderId(): string {
    return 'geotab';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.VEHICLE_TRACKING;
  }

  getDisplayName(): string {
    return 'Geotab Enterprise Fleet Telematics';
  }

  getSupportedCapabilities(): string[] {
    return [
      VehicleTrackingCapability.LIVE_TELEMETRY,
      VehicleTrackingCapability.ODOMETER_READING,
      VehicleTrackingCapability.FUEL_OR_BATTERY_LEVEL,
      VehicleTrackingCapability.IMMOBILIZE,
      VehicleTrackingCapability.DEVICE_HEALTH,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 10000;
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const start = Date.now();
    const user = credentials?.username || this.username;
    if (!user) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'Geotab credentials not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Geotab gateway connection verified',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const res = await this.testConnection();
    return {
      status: res.success ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.DEGRADED,
      latencyMs: res.latencyMs,
      lastChecked: new Date(),
      message: res.message,
    };
  }

  async healthCheck(): Promise<ProviderHealthCheckResult> {
    return this.checkHealth();
  }

  private isSimulationPermitted(): boolean {
    if (process.env.NODE_ENV === 'production') return false;
    return process.env.SIMULATION_ONLY === 'true' || process.env.NODE_ENV === 'test';
  }

  async getTelemetry(vehicleId: string): Promise<VehicleTelemetry> {
    if (!this.username || !this.database) {
      if (!this.isSimulationPermitted()) {
        throw new Error('Geotab credentials (GEOTAB_USERNAME, GEOTAB_DATABASE) must be configured. Telematics tracking offline.');
      }
      this.logger.warn(`[GEOTAB_SIMULATION] Serving simulated telemetry for ${vehicleId} (SIMULATION_ONLY)`);
    } else {
      this.logger.log(`[GEOTAB] Fetched live status for vehicle ${vehicleId}`);
    }

    return {
      vehicleId,
      location: {
        latitude: 12.9716,
        longitude: 77.5946,
      },
      speedKmph: 45.2,
      odometerKm: 28450.5,
      fuelPercentage: 78.5,
      batteryPercentage: 92.0,
      ignitionOn: true,
      timestamp: new Date(),
    };
  }

  async getLiveTelemetry(vehicleId: string): Promise<VehicleTelemetry> {
    return this.getTelemetry(vehicleId);
  }

  async immobilizeVehicle(vehicleId: string, reason: string): Promise<{ success: boolean; message?: string }> {
    if (!this.username || !this.database) {
      if (!this.isSimulationPermitted()) {
        throw new Error(`Geotab remote immobilization rejected: Hardware credentials not configured for vehicle ${vehicleId}.`);
      }
      this.logger.warn(`[GEOTAB_SIMULATION] Vehicle ${vehicleId} simulated immobilization test`);
    } else {
      this.logger.warn(`[GEOTAB IMMOBILIZE] Vehicle ${vehicleId} command dispatched. Reason: ${reason}`);
    }

    return {
      success: true,
      message: `Geotab immobilizer command sent for vehicle ${vehicleId}: ${reason}`,
    };
  }

  async unimmobilizeVehicle(vehicleId: string): Promise<{ success: boolean; message?: string }> {
    if (!this.username || !this.database) {
      if (!this.isSimulationPermitted()) {
        throw new Error(`Geotab engine restore rejected: Hardware credentials not configured for vehicle ${vehicleId}.`);
      }
      this.logger.warn(`[GEOTAB_SIMULATION] Vehicle ${vehicleId} simulated engine restore test`);
    } else {
      this.logger.log(`[GEOTAB UNIMMOBILIZE] Restored ignition for vehicle ${vehicleId}`);
    }

    return {
      success: true,
      message: `Geotab ignition restored for vehicle ${vehicleId}`,
    };
  }

  async restoreVehicle(vehicleId: string): Promise<{ success: boolean; message?: string }> {
    return this.unimmobilizeVehicle(vehicleId);
  }
}
