import { BaseProvider } from './provider.interface';
import { LatLngPoint } from './maps-provider.interface';

export enum VehicleTrackingCapability {
  LIVE_TELEMETRY = 'LIVE_TELEMETRY',
  ODOMETER_READING = 'ODOMETER_READING',
  FUEL_OR_BATTERY_LEVEL = 'FUEL_OR_BATTERY_LEVEL',
  IMMOBILIZE = 'IMMOBILIZE',
  DEVICE_HEALTH = 'DEVICE_HEALTH',
}

export interface VehicleTelemetry {
  vehicleId: string;
  location: LatLngPoint;
  speedKmph: number;
  odometerKm: number;
  fuelPercentage?: number;
  batteryPercentage?: number;
  ignitionOn: boolean;
  timestamp: Date;
}

export interface VehicleTrackingProvider extends BaseProvider {
  getTelemetry(vehicleId: string): Promise<VehicleTelemetry>;
  immobilizeVehicle(vehicleId: string, reason: string): Promise<{ success: boolean; message?: string }>;
  unimmobilizeVehicle(vehicleId: string): Promise<{ success: boolean; message?: string }>;
}
