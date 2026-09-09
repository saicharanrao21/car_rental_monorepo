import {
  IsArray,
  IsEnum,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Min,
  Max,
} from 'class-validator';
import { IntegrationCategory } from '../../registry/provider.types';
import {
  CertificationLevel,
  ProviderPricingType,
  ProviderStatus,
} from '../../directory/provider-directory.types';
import {
  IncidentSeverity,
  IncidentStatus,
  IncidentType,
} from '../../governance/provider-incident.types';
import { ProviderChangeType } from '../../governance/provider-change-audit.service';
import { SimulationScenario } from '../../runtime/runtime.types';

export class DirectoryFilterDto {
  @IsEnum(IntegrationCategory)
  @IsOptional()
  category?: IntegrationCategory;

  @IsString()
  @IsOptional()
  country?: string;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  capability?: string;

  @IsEnum(CertificationLevel)
  @IsOptional()
  certificationLevel?: CertificationLevel;

  @IsEnum(ProviderPricingType)
  @IsOptional()
  pricingType?: ProviderPricingType;

  @IsEnum(ProviderStatus)
  @IsOptional()
  status?: ProviderStatus;

  @IsString()
  @IsOptional()
  search?: string;
}

export class ScoreCompareDto {
  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsString()
  @IsOptional()
  country?: string;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  requiredCapabilities?: string[];

  @IsNumber()
  @IsOptional()
  maxAcceptableLatencyMs?: number;
}

export class CreateManualIncidentDto {
  @IsString()
  providerId: string;

  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsString()
  title: string;

  @IsEnum(IncidentSeverity)
  severity: IncidentSeverity;

  @IsEnum(IncidentType)
  incidentType: IncidentType;

  @IsString()
  @IsOptional()
  reason?: string;

  @IsObject()
  @IsOptional()
  metadata?: Record<string, any>;
}

export class UpdateIncidentStatusDto {
  @IsEnum(IncidentStatus)
  @IsOptional()
  status?: IncidentStatus;

  @IsEnum(IncidentSeverity)
  @IsOptional()
  severity?: IncidentSeverity;

  @IsString()
  @IsOptional()
  reason?: string;

  @IsString()
  @IsOptional()
  resolutionNotes?: string;
}

export class ResolveIncidentDto {
  @IsString()
  resolutionNotes: string;
}

export class ManualChangeAuditDto {
  @IsString()
  providerId: string;

  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsEnum(ProviderChangeType)
  changeType: ProviderChangeType;

  @IsString()
  @IsOptional()
  environment?: string;

  @IsString()
  reason: string;

  @IsObject()
  @IsOptional()
  beforeSnapshot?: Record<string, any>;

  @IsObject()
  @IsOptional()
  afterSnapshot?: Record<string, any>;
}

export class OnboardingSubmitDto {
  @IsString()
  providerId: string;

  @IsString()
  displayName: string;

  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsString()
  description: string;

  @IsArray()
  @IsString({ each: true })
  supportedCountries: string[];

  @IsArray()
  @IsString({ each: true })
  supportedCurrencies: string[];

  @IsArray()
  @IsString({ each: true })
  supportedCapabilities: string[];

  @IsNumber()
  @Min(1)
  @Max(100)
  priority: number;

  @IsString()
  @IsOptional()
  websiteUrl?: string;

  @IsString()
  @IsOptional()
  documentationUrl?: string;

  @IsObject()
  @IsOptional()
  pricing?: any;

  @IsObject()
  @IsOptional()
  sla?: any;
}

export class RunSimulationLabDto {
  @IsString()
  providerId: string;

  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsEnum(SimulationScenario)
  scenario: SimulationScenario;

  @IsNumber()
  @IsOptional()
  latencyMs?: number;

  @IsObject()
  @IsOptional()
  payload?: Record<string, any>;
}
