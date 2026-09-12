import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { IntegrationRuntimeService } from '../integrations/runtime/integration-runtime.service';
import { IntegrationCategory } from '../integrations/registry/provider.types';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import {
  FleetOperationalState,
  VehicleTelemetrySnapshot,
} from './fleet-domain.types';

export class IngestTelemetryDto {
  carId!: string;
  deviceId?: string;
  provider?: string;
  latitude!: number;
  longitude!: number;
  altitude?: number;
  speedKmH!: number;
  headingDegrees?: number;
  odometerKm!: number;
  engineHours?: number;
  ignitionStatus!: 'ON' | 'OFF';
  fuelLevelPercent?: number;
  batteryLevelPercent?: number;
  batteryVoltage?: number;
  rawAttributes?: Record<string, any>;
}

@Injectable()
export class FleetTelematicsService {
  private readonly logger = new Logger(FleetTelematicsService.name);

  // In-memory store for latest telemetry snapshots
  private readonly telemetryStore: Map<string, VehicleTelemetrySnapshot> = new Map();
  private static readonly STALE_HEARTBEAT_THRESHOLD_MS = 30 * 60 * 1000; // 30 minutes

  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycleService: FleetLifecycleService,
    @Optional() private readonly runtimeService?: IntegrationRuntimeService,
  ) {}

  /**
   * Ingests and normalizes telemetry from a GPS/telematics IoT device.
   */
  async ingestTelemetry(dto: IngestTelemetryDto): Promise<VehicleTelemetrySnapshot> {
    if (!dto.carId) {
      throw new BadRequestException('carId is required for telemetry ingestion');
    }

    const now = new Date().toISOString();
    const snapshot: VehicleTelemetrySnapshot = {
      carId: dto.carId,
      deviceId: dto.deviceId || `device_${dto.carId.substring(0, 6)}`,
      provider: dto.provider || 'traccar',
      latitude: dto.latitude,
      longitude: dto.longitude,
      altitude: dto.altitude,
      speedKmH: dto.speedKmH,
      headingDegrees: dto.headingDegrees,
      odometerKm: dto.odometerKm,
      engineHours: dto.engineHours,
      ignitionStatus: dto.ignitionStatus,
      fuelLevelPercent: dto.fuelLevelPercent,
      batteryLevelPercent: dto.batteryLevelPercent,
      batteryVoltage: dto.batteryVoltage,
      isGpsOnline: true,
      lastHeartbeatAt: now,
      rawAttributes: dto.rawAttributes,
    };

    this.telemetryStore.set(dto.carId, snapshot);

    // If vehicle was previously marked GPS_OFFLINE, restore it to ACTIVE/AVAILABLE
    try {
      const currentState = await this.lifecycleService.getVehicleState(dto.carId);
      if (currentState === FleetOperationalState.GPS_OFFLINE) {
        await this.lifecycleService.transitionState(
          dto.carId,
          FleetOperationalState.AVAILABLE,
          { id: 'telematics_engine', role: 'SYSTEM' },
          { reason: `GPS heartbeat restored from provider: ${snapshot.provider}` },
        );
      }
    } catch (err: any) {
      this.logger.debug(`Could not auto-restore state for ${dto.carId}: ${err.message}`);
    }

    return snapshot;
  }

  /**
   * Retrieves the latest normalized telemetry snapshot for a vehicle.
   * Seamlessly queries IntegrationRuntime if live lookup is requested.
   */
  async getLatestTelemetry(carId: string): Promise<VehicleTelemetrySnapshot> {
    if (this.telemetryStore.has(carId)) {
      const snapshot = this.telemetryStore.get(carId)!;
      // Check if telemetry is stale (>30 minutes)
      const heartbeatAge = Date.now() - new Date(snapshot.lastHeartbeatAt).getTime();
      if (heartbeatAge > FleetTelematicsService.STALE_HEARTBEAT_THRESHOLD_MS) {
        snapshot.isGpsOnline = false;
        await this.handleGpsSignalLoss(carId);
      }
      return snapshot;
    }

    // Try live pull through IntegrationRuntimeService
    if (this.runtimeService) {
      try {
        const res = await this.runtimeService.execute<any, any>({
          category: IntegrationCategory.VEHICLE_TRACKING,
          capability: 'LIVE_LOCATION',
          payload: { vehicleId: carId, carId },
        });
        if (res.success && res.data) {
          const snapshot: VehicleTelemetrySnapshot = {
            carId,
            deviceId: res.data.deviceId || 'live_unit',
            provider: res.providerId || 'traccar',
            latitude: res.data.latitude ?? 12.9716,
            longitude: res.data.longitude ?? 77.5946,
            speedKmH: res.data.speed ?? 0,
            odometerKm: res.data.odometer ?? 14250,
            ignitionStatus: res.data.ignition ? 'ON' : 'OFF',
            fuelLevelPercent: res.data.fuelPercent ?? 85,
            isGpsOnline: true,
            lastHeartbeatAt: new Date().toISOString(),
          };
          this.telemetryStore.set(carId, snapshot);
          return snapshot;
        }
      } catch (err: any) {
        this.logger.warn(`Could not pull live telematics for ${carId}: ${err.message}`);
      }
    }

    // Fallback baseline when no live hardware or telemetry exists
    return {
      carId,
      provider: 'none',
      latitude: 0,
      longitude: 0,
      speedKmH: 0,
      odometerKm: 0,
      ignitionStatus: 'OFF',
      fuelLevelPercent: 0,
      isGpsOnline: false,
      lastHeartbeatAt: new Date(0).toISOString(),
    };
  }

  /**
   * Dispatches remote vehicle immobilization command via telematics adapter.
   */
  async immobilizeVehicle(carId: string, reason: string): Promise<{ success: boolean; provider: string; message: string }> {
    if (this.runtimeService) {
      try {
        const res = await this.runtimeService.execute<any, any>({
          category: IntegrationCategory.VEHICLE_TRACKING,
          capability: 'IMMOBILIZE',
          payload: { vehicleId: carId, carId, reason },
        });
        if (res.success) {
          return {
            success: true,
            provider: res.providerId || 'traccar',
            message: `Starter circuit cut command confirmed by ${res.providerId}`,
          };
        }
        const errDetail = typeof res.error === 'object' ? (res.error?.message || JSON.stringify(res.error)) : (res.error || 'Command failed');
        throw new ServiceUnavailableException(
          `Vehicle immobilization command rejected by hardware gateway (${res.providerId}): ${errDetail}`,
        );
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`Immobilization failed for ${carId}: ${err.message}`);
      }
    }

    const isSim = process.env.NODE_ENV !== 'production' && process.env.SIMULATION_ONLY === 'true';
    if (isSim) {
      return {
        success: false,
        provider: 'simulation_engine',
        message: `[SIMULATION ONLY] Vehicle ${carId} remote immobilization cannot be executed without configured IoT hardware gateway.`,
      };
    }

    throw new ServiceUnavailableException(
      `Remote vehicle immobilization unavailable: No active telematics IoT gateway configured for vehicle ${carId}. Dispatch blocked.`,
    );
  }

  /**
   * Internal handler when GPS signal heartbeat is lost.
   */
  private async handleGpsSignalLoss(carId: string) {
    try {
      const currentState = await this.lifecycleService.getVehicleState(carId);
      if (currentState === FleetOperationalState.AVAILABLE) {
        await this.lifecycleService.transitionState(
          carId,
          FleetOperationalState.GPS_OFFLINE,
          { id: 'telematics_heartbeat_monitor', role: 'SYSTEM' },
          { reason: 'Telematics heartbeat ceased for >30 minutes. Operational dispatch blocked.' },
        );
      }
    } catch (err: any) {
      this.logger.debug(`Could not trigger GPS_OFFLINE for ${carId}: ${err.message}`);
    }
  }
}
