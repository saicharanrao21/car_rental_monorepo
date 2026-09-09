import { Role } from '@prisma/client';

/**
 * 19-State Enterprise Operational Lifecycle State Machine
 */
export enum FleetOperationalState {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  AVAILABLE = 'AVAILABLE',
  RESERVED = 'RESERVED',
  PICKUP_PENDING = 'PICKUP_PENDING',
  ON_RENT = 'ON_RENT',
  EXTENSION_PENDING = 'EXTENSION_PENDING',
  RETURN_PENDING = 'RETURN_PENDING',
  INSPECTION = 'INSPECTION',
  CLEANING = 'CLEANING',
  MAINTENANCE = 'MAINTENANCE',
  ACCIDENT = 'ACCIDENT',
  DAMAGED = 'DAMAGED',
  QUARANTINED = 'QUARANTINED',
  COMPLIANCE_BLOCKED = 'COMPLIANCE_BLOCKED',
  GPS_OFFLINE = 'GPS_OFFLINE',
  INACTIVE = 'INACTIVE',
  RETIRED = 'RETIRED',
  SOLD = 'SOLD',
}

/**
 * Enterprise Vehicle Classification
 */
export enum VehicleClass {
  ECONOMY = 'ECONOMY',
  COMPACT = 'COMPACT',
  MIDSIZE = 'MIDSIZE',
  STANDARD = 'STANDARD',
  FULLSIZE = 'FULLSIZE',
  PREMIUM = 'PREMIUM',
  LUXURY = 'LUXURY',
  SUV_COMPACT = 'SUV_COMPACT',
  SUV_FULLSIZE = 'SUV_FULLSIZE',
  VAN_PASSENGER = 'VAN_PASSENGER',
  COMMERCIAL = 'COMMERCIAL',
}

/**
 * Transmission and Powertrain Types
 */
export enum TransmissionType {
  MANUAL = 'MANUAL',
  AUTOMATIC = 'AUTOMATIC',
  AMT = 'AMT',
  CVT = 'CVT',
  DUAL_CLUTCH = 'DUAL_CLUTCH',
}

export enum VehicleFuelType {
  PETROL = 'PETROL',
  DIESEL = 'DIESEL',
  CNG = 'CNG',
  HYBRID = 'HYBRID',
  ELECTRIC = 'ELECTRIC',
}

/**
 * Inspection Types & Status
 */
export enum InspectionType {
  PRE_RENTAL = 'PRE_RENTAL',
  PICKUP = 'PICKUP',
  RETURN = 'RETURN',
  POST_RENTAL = 'POST_RENTAL',
  MAINTENANCE = 'MAINTENANCE',
  ACCIDENT = 'ACCIDENT',
  PERIODIC = 'PERIODIC',
}

export enum InspectionItemStatus {
  PASS = 'PASS',
  FAIL = 'FAIL',
  ATTENTION_REQUIRED = 'ATTENTION_REQUIRED',
  NOT_APPLICABLE = 'NOT_APPLICABLE',
}

/**
 * Damage Severity & Location
 */
export enum DamageSeverity {
  COSMETIC = 'COSMETIC',
  MINOR_SCRATCH = 'MINOR_SCRATCH',
  MODERATE_DENT = 'MODERATE_DENT',
  MAJOR_DAMAGE = 'MAJOR_DAMAGE',
  STRUCTURAL = 'STRUCTURAL',
  TOTAL_LOSS = 'TOTAL_LOSS',
}

export enum DamageLocation {
  FRONT_BUMPER = 'FRONT_BUMPER',
  REAR_BUMPER = 'REAR_BUMPER',
  HOOD = 'HOOD',
  TRUNK = 'TRUNK',
  WINDSHIELD = 'WINDSHIELD',
  ROOF = 'ROOF',
  LEFT_FRONT_DOOR = 'LEFT_FRONT_DOOR',
  LEFT_REAR_DOOR = 'LEFT_REAR_DOOR',
  RIGHT_FRONT_DOOR = 'RIGHT_FRONT_DOOR',
  RIGHT_REAR_DOOR = 'RIGHT_REAR_DOOR',
  LEFT_FENDER = 'LEFT_FENDER',
  RIGHT_FENDER = 'RIGHT_FENDER',
  WHEELS_TYRES = 'WHEELS_TYRES',
  UNDERCARRIAGE = 'UNDERCARRIAGE',
  INTERIOR_CABIN = 'INTERIOR_CABIN',
}

/**
 * Compliance & Regulatory Document Types
 */
export enum ComplianceDocumentType {
  REGISTRATION_CERTIFICATE = 'REGISTRATION_CERTIFICATE',
  INSURANCE_POLICY = 'INSURANCE_POLICY',
  COMMERCIAL_PERMIT = 'COMMERCIAL_PERMIT',
  FITNESS_CERTIFICATE = 'FITNESS_CERTIFICATE',
  POLLUTION_UNDER_CONTROL = 'POLLUTION_UNDER_CONTROL',
  ROAD_TAX_RECEIPT = 'ROAD_TAX_RECEIPT',
  INTERSTATE_PERMIT = 'INTERSTATE_PERMIT',
}

export enum ComplianceStatus {
  VALID = 'VALID',
  EXPIRING_SOON = 'EXPIRING_SOON',
  EXPIRED = 'EXPIRED',
  PENDING_VERIFICATION = 'PENDING_VERIFICATION',
  REJECTED = 'REJECTED',
  SUSPENDED = 'SUSPENDED',
}

/**
 * 16-Point Inspection Checklist Structure
 */
export interface InspectionChecklistPoint {
  code: string;
  name: string;
  category: 'EXTERIOR' | 'INTERIOR' | 'MECHANICAL' | 'DOCUMENTATION' | 'SAFETY';
  status: InspectionItemStatus;
  notes?: string;
  photoUrls?: string[];
}

export interface DamageMarker {
  id: string;
  location: DamageLocation;
  severity: DamageSeverity;
  description: string;
  photoUrls: string[];
  isPreExisting: boolean;
  estimatedRepairCost?: number;
  detectedByAi?: boolean;
  aiConfidence?: number;
}

export interface InspectionRecord {
  id: string;
  carId: string;
  bookingId?: string;
  inspectionType: InspectionType;
  inspectorId: string;
  inspectorName?: string;
  odometerReadingKm: number;
  fuelLevelPercent: number;
  batteryLevelPercent?: number;
  checklist: InspectionChecklistPoint[];
  damages: DamageMarker[];
  overallCondition: 'EXCELLENT' | 'GOOD' | 'FAIR' | 'REQUIRES_ATTENTION' | 'GROUNDED';
  passed: boolean;
  signatures?: {
    inspectorSignatureUrl?: string;
    customerSignatureUrl?: string;
  };
  createdAt: string;
}

/**
 * Vehicle Compliance Document Record
 */
export interface VehicleComplianceRecord {
  id: string;
  carId: string;
  documentType: ComplianceDocumentType;
  documentNumber: string;
  issuingAuthority?: string;
  issueDate: string;
  expiryDate: string;
  documentUrl?: string;
  status: ComplianceStatus;
  daysUntilExpiry: number;
  isMandatoryForRental: boolean;
  verifiedAt?: string;
  verifiedBy?: string;
}

/**
 * Vehicle Telematics & Telemetry Snapshot
 */
export interface VehicleTelemetrySnapshot {
  carId: string;
  deviceId?: string;
  provider: string; // 'traccar' | 'teltonika' | 'geotab' | 'samsara' | 'mock'
  latitude: number;
  longitude: number;
  altitude?: number;
  speedKmH: number;
  headingDegrees?: number;
  odometerKm: number;
  engineHours?: number;
  ignitionStatus: 'ON' | 'OFF';
  fuelLevelPercent?: number;
  batteryLevelPercent?: number;
  batteryVoltage?: number;
  isGpsOnline: boolean;
  lastHeartbeatAt: string;
  rawAttributes?: Record<string, any>;
}

/**
 * Explainable Availability Result
 */
export interface FleetAvailabilityExplanation {
  carId: string;
  isAvailable: boolean;
  operationalState: FleetOperationalState;
  reason?: string;
  blockingFactors?: Array<{
    type: 'RENTAL' | 'RESERVATION' | 'MAINTENANCE' | 'COMPLIANCE' | 'CLEANING' | 'GPS_OFFLINE';
    details: string;
    blockedUntil?: string;
  }>;
  nextAvailableAt?: string;
  turnaroundBufferMinutes: number;
  alternativeVehicles?: Array<{
    carId: string;
    make: string;
    model: string;
    vehicleClass: VehicleClass;
    branchId: string;
    branchName: string;
    pricePerDay: number;
    distanceKm?: number;
  }>;
}

/**
 * Fleet Command Centre KPIs
 */
export interface FleetKpis {
  totalVehicles: number;
  availableVehicles: number;
  reservedVehicles: number;
  onRentVehicles: number;
  maintenanceVehicles: number;
  damagedVehicles: number;
  complianceBlockedVehicles: number;
  gpsOfflineVehicles: number;
  fleetUtilizationRate: number; // 0.0 - 100.0%
  branchBreakdown: Array<{
    branchId: string;
    branchName: string;
    total: number;
    available: number;
    onRent: number;
    utilizationRate: number;
  }>;
  vehicleClassBreakdown: Record<string, number>;
  upcomingComplianceExpiriesCount: number; // <= 30 days
}

/**
 * Branch Fleet Rebalance Recommendation
 */
export interface BranchRebalanceRecommendation {
  sourceBranchId: string;
  sourceBranchName: string;
  targetBranchId: string;
  targetBranchName: string;
  recommendedVehicleClass: VehicleClass;
  recommendedCount: number;
  rationale: string;
  confidenceScore: number;
}

/**
 * Fleet Domain Events
 */
export interface FleetDomainEvent {
  eventType:
    | 'vehicle.created'
    | 'vehicle.activated'
    | 'vehicle.assigned'
    | 'vehicle.transferred'
    | 'vehicle.reserved'
    | 'vehicle.rental.started'
    | 'vehicle.returned'
    | 'vehicle.inspection.completed'
    | 'vehicle.damage.detected'
    | 'vehicle.maintenance.required'
    | 'vehicle.compliance.expiring'
    | 'vehicle.compliance.expired'
    | 'vehicle.gps.offline'
    | 'vehicle.gps.online'
    | 'vehicle.status.changed';
  carId: string;
  tenantId?: string;
  vendorId?: string;
  branchId?: string;
  timestamp: string;
  actorId?: string;
  payload: Record<string, any>;
}
