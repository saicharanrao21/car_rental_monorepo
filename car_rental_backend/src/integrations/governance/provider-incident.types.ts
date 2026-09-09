import { IntegrationCategory } from '../registry/provider.types';

export enum IncidentSeverity {
  CRITICAL = 'CRITICAL',
  MAJOR = 'MAJOR',
  MEDIUM = 'MEDIUM',
  LOW = 'LOW',
}

export enum IncidentStatus {
  DETECTED = 'DETECTED',
  INVESTIGATING = 'INVESTIGATING',
  IDENTIFIED = 'IDENTIFIED',
  MONITORING = 'MONITORING',
  RESOLVED = 'RESOLVED',
}

export enum IncidentType {
  OUTAGE = 'OUTAGE',
  DEGRADATION = 'DEGRADATION',
  CREDENTIAL_FAILURE = 'CREDENTIAL_FAILURE',
  RATE_LIMIT_EXHAUSTION = 'RATE_LIMIT_EXHAUSTION',
  WEBHOOK_FAILURE = 'WEBHOOK_FAILURE',
  CONFIGURATION_FAILURE = 'CONFIGURATION_FAILURE',
  CIRCUIT_TRIP = 'CIRCUIT_TRIP',
}

export enum DetectionSource {
  CIRCUIT_BREAKER = 'CIRCUIT_BREAKER',
  HEALTH_PROBE = 'HEALTH_PROBE',
  RUNTIME_FAILURE = 'RUNTIME_FAILURE',
  RATE_LIMITER = 'RATE_LIMITER',
  ADMIN_MANUAL = 'ADMIN_MANUAL',
}

export interface ProviderIncidentRecord {
  id: string;
  providerId: string;
  category: IntegrationCategory;
  title: string;
  status: IncidentStatus;
  severity: IncidentSeverity;
  incidentType: IncidentType;
  detectionSource: DetectionSource;
  circuitState: string;
  errorRate?: number;
  failureCount: number;
  startedAt: Date;
  resolvedAt?: Date;
  reason?: string;
  acknowledgedBy?: string;
  acknowledgedAt?: Date;
  resolutionNotes?: string;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateIncidentDto {
  providerId: string;
  category: IntegrationCategory;
  title: string;
  severity: IncidentSeverity;
  incidentType: IncidentType;
  detectionSource: DetectionSource;
  reason?: string;
  circuitState?: string;
  metadata?: Record<string, any>;
}

export interface UpdateIncidentDto {
  status?: IncidentStatus;
  severity?: IncidentSeverity;
  reason?: string;
  resolutionNotes?: string;
  metadata?: Record<string, any>;
}

export interface IncidentFilterQuery {
  providerId?: string;
  category?: IntegrationCategory;
  status?: IncidentStatus;
  severity?: IncidentSeverity;
  from?: Date;
  to?: Date;
  limit?: number;
}
