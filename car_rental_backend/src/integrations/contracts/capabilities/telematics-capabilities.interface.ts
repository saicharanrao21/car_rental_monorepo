export enum TelematicsCapability {
  GPS_POSITION = 'GPS_POSITION',
  LIVE_LOCATION = 'LIVE_LOCATION',
  TRIP_TRACKING = 'TRIP_TRACKING',
  GEOFENCE_CHECK = 'GEOFENCE_CHECK',
  GEOFENCE_EVENT = 'GEOFENCE_EVENT',
  IMMOBILIZE = 'IMMOBILIZE',
  RESTORE_ENGINE = 'RESTORE_ENGINE',
  DIAGNOSTICS = 'DIAGNOSTICS',
  DEVICE_HEALTH = 'DEVICE_HEALTH',
  TELEMETRY_HISTORY = 'TELEMETRY_HISTORY',
  DRIVER_BEHAVIOR = 'DRIVER_BEHAVIOR',
}

export interface TelematicsPosition {
  latitude: number;
  longitude: number;
  altitudeMeters?: number;
  speedKph: number;
  courseDegrees?: number;
  accuracyMeters?: number;
  timestamp: Date;
}

export interface NormalizedTelematicsEvent {
  deviceId: string;
  vehicleId?: string;
  timestamp: Date;
  position: TelematicsPosition;
  ignitionOn: boolean;
  odometerKm: number;
  fuelLevelPercent?: number;
  batteryVoltage?: number;
  engineHours?: number;
  isMoving: boolean;
  harshBraking?: boolean;
  harshAcceleration?: boolean;
  harshCornering?: boolean;
  tamperAlert?: boolean;
  powerDisconnected?: boolean;
  rawPayload?: any;
}

export interface GeofenceEvent {
  geofenceId: string;
  geofenceName: string;
  deviceId: string;
  eventType: 'ENTER' | 'EXIT' | 'DWELL';
  timestamp: Date;
  coordinates: {
    latitude: number;
    longitude: number;
  };
}

export interface ImmobilizationCommandRequest {
  deviceId: string;
  action: 'IMMOBILIZE' | 'RESTORE';
  reason?: string;
  initiatedBy?: string;
}

export interface ImmobilizationCommandResult {
  deviceId: string;
  commandId: string;
  status: 'PENDING' | 'EXECUTED' | 'FAILED' | 'REJECTED';
  action: 'IMMOBILIZE' | 'RESTORE';
  message: string;
  timestamp: Date;
}

export interface DeviceStatusResult {
  deviceId: string;
  isOnline: boolean;
  lastSeenAt: Date;
  lastPosition: TelematicsPosition;
  batteryHealthPercent?: number;
  satelliteCount?: number;
  networkSignalRssi?: number;
  firmwareVersion?: string;
}

export interface TelematicsHistoryRequest {
  deviceId: string;
  fromTime: Date;
  toTime: Date;
  limit?: number;
}
