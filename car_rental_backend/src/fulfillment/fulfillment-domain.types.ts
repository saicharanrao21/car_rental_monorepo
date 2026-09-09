import {
  FulfillmentStage,
  Role,
  CarCategory,
  BookingStatus,
} from '@prisma/client';

export { FulfillmentStage };

export interface StartPreparationRequest {
  bookingId: string;
  assignedStaffId?: string;
  notes?: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
}

export interface MarkCleanedRequest {
  bookingId: string;
  assignedStaffId?: string;
  cleaningChecklist?: string[];
  actorId: string;
  actorRole: Role | 'SYSTEM';
}

export interface MarkInspectedRequest {
  bookingId: string;
  assignedStaffId?: string;
  inspectionNotes?: string;
  odometerReading?: number;
  fuelPercent?: number;
  actorId: string;
  actorRole: Role | 'SYSTEM';
}

export interface MarkReadyForPickupRequest {
  bookingId: string;
  bayNumber?: string;
  keyLocation?: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
}

export interface CustomerArrivalRequest {
  bookingId: string;
  deskNumber?: string;
  verifiedIdentity?: boolean;
  notes?: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
}

export interface FulfillmentTransitionResult {
  success: boolean;
  fulfillmentId: string;
  bookingId: string;
  previousStage: FulfillmentStage;
  newStage: FulfillmentStage;
  stageTimestamp: string;
  message: string;
  metadata?: Record<string, any>;
}

export interface BranchOperationalQueueItem {
  bookingId: string;
  customerId: string;
  customerName: string;
  customerPhone?: string;
  vendorId: string;
  branchId?: string;
  carId?: string;
  vehicleName: string;
  registrationNumber?: string;
  vehicleClass: CarCategory;
  startDate: string;
  endDate: string;
  stage: FulfillmentStage;
  bookingStatus: BookingStatus;
  isKycVerified: boolean;
  isVehicleReady: boolean;
  customerArrived: boolean;
  overdueMinutes?: number;
  assignedStaffId?: string;
}

export interface BranchQueueSummary {
  branchId: string;
  totalActive: number;
  pendingAllocationCount: number;
  preparationQueueCount: number;
  readyForPickupCount: number;
  customerArrivalQueueCount: number;
  activeRentalsCount: number;
  returnQueueCount: number;
  overdueReturnCount: number;
  items: BranchOperationalQueueItem[];
}
