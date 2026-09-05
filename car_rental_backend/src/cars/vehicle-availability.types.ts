import { VehicleBlockType, VehicleHoldStatus, Role, BookingStatus } from '@prisma/client';

export interface VehicleAvailabilityConflict {
  type: 'BOOKING' | 'MAINTENANCE' | 'BLOCK' | 'HOLD' | 'LOCATION_CLOSURE';
  id?: string;
  startDate: Date;
  endDate: Date;
  reason?: string;
  status?: string;
}

export interface VehicleAvailabilityResult {
  available: boolean;
  carId: string;
  evaluatedInterval: {
    startDate: string;
    endDate: string;
  };
  reason?: string;
  conflicts: VehicleAvailabilityConflict[];
}

export interface AvailabilityQueryDto {
  startDate: string;
  endDate: string;
  city?: string;
  pickupHubId?: string;
  tripType?: string;
  carType?: string;
  fuelType?: string;
  seating?: number;
  minPrice?: number;
  maxPrice?: number;
  isAC?: boolean;
  page?: number;
  limit?: number;
}

export interface CreateVehicleHoldDto {
  startDate: string;
  endDate: string;
  ttlSeconds?: number;
  idempotencyKey?: string;
}

export interface CreateVehicleBlockDto {
  startDate: string;
  endDate: string;
  blockType?: VehicleBlockType;
  reason?: string;
}

export interface AvailabilityTimelineEntry {
  type: 'AVAILABLE' | 'BOOKING' | 'MAINTENANCE' | 'BLOCK' | 'HOLD' | 'CLOSURE';
  id?: string;
  status?: string;
  startDate: string;
  endDate: string;
  reason?: string;
  metadata?: Record<string, any>;
}
