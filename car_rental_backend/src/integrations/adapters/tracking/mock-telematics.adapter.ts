import { Injectable } from '@nestjs/common';
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
export class MockTelematicsAdapter implements VehicleTrackingProvider {
  getProviderId(): string {
    return 'mock_telematics';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.VEHICLE_TRACKING;
  }

  getDisplayName(): string {
    return 'Mock Telematics & Fleet Tracking Provider';
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
    return 3000;
  }

  async getTelemetry(vehicleId: string): Promise<VehicleTelemetry> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'CRITICAL SECURITY ERROR: MockTelematicsAdapter cannot be invoked in production. A certified telematics gateway (e.g. Traccar, Geotab) is required.',
      );
    }
    return {
      vehicleId,
      location: { latitude: 12.9716, longitude: 77.5946 },
      speedKmph: 0,
      odometerKm: 25400,
      fuelPercentage: 85,
      batteryPercentage: 98,
      ignitionOn: false,
      timestamp: new Date(),
    };
  }

  async immobilizeVehicle(vehicleId: string, reason: string): Promise<{ success: boolean; message?: string }> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'CRITICAL SECURITY ERROR: MockTelematicsAdapter immobilization cannot be invoked in production.',
      );
    }
    return {
      success: true,
      message: `Vehicle ${vehicleId} immobilized successfully. Reason: ${reason}`,
    };
  }

  async unimmobilizeVehicle(vehicleId: string): Promise<{ success: boolean; message?: string }> {
    return {
      success: true,
      message: `Vehicle ${vehicleId} unimmobilized successfully.`,
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Telematics is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock Telematics connection test successful',
    };
  }
}
