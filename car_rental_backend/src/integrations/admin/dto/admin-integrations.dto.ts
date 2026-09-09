import {
  IsBoolean,
  IsEnum,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
} from 'class-validator';
import { IntegrationCategory } from '../../registry/provider.types';

export class UpdateIntegrationConfigDto {
  @IsBoolean()
  @IsOptional()
  isEnabled?: boolean;

  @IsNumber()
  @IsOptional()
  priority?: number;

  @IsObject()
  @IsOptional()
  credentials?: Record<string, string>;

  @IsObject()
  @IsOptional()
  settings?: Record<string, any>;

  @IsString()
  @IsOptional()
  vendorId?: string;

  @IsString()
  @IsOptional()
  branchId?: string;
}

export class ToggleProviderDto {
  @IsBoolean()
  enabled: boolean;
}

export class SetActiveProviderDto {
  @IsString()
  @IsOptional()
  vendorId?: string;

  @IsString()
  @IsOptional()
  branchId?: string;
}

export class TestConnectionDto {
  @IsObject()
  @IsOptional()
  credentials?: Record<string, string>;
}

export class UpdateActivationStateDto {
  @IsString()
  activationState: string;
}

export class ValidateCredentialsDto {
  @IsObject()
  credentials: Record<string, any>;

  @IsString()
  @IsOptional()
  environment?: string;
}

export class RegisterCatalogProviderDto {
  @IsString()
  providerId: string;

  @IsEnum(IntegrationCategory)
  category: IntegrationCategory;

  @IsString()
  name: string;

  @IsString()
  tagline: string;

  @IsString()
  description: string;

  @IsString()
  icon: string;

  @IsString()
  websiteUrl: string;

  @IsObject()
  documentation: {
    overview: string;
    docsUrl: string;
    setupGuide: string;
    webhookGuide?: string;
    supportEmail?: string;
  };

  @IsString()
  version: string;

  @IsString()
  @IsOptional()
  apiVersion?: string;

  @IsString()
  author: string;

  @IsOptional()
  tags?: string[];

  @IsOptional()
  supportedEnvironments?: string[];

  @IsString()
  @IsOptional()
  defaultEnvironment?: string;

  @IsOptional()
  credentialSchema?: any[];

  @IsOptional()
  supportedCapabilities?: string[];

  @IsOptional()
  supportedCurrencies?: string[];

  @IsOptional()
  supportedCountries?: string[];

  @IsOptional()
  supportedWebhookEvents?: string[];

  @IsString()
  @IsOptional()
  webhookSignatureHeader?: string;

  @IsBoolean()
  @IsOptional()
  platformAvailability?: boolean;

  @IsOptional()
  tenantTierAvailability?: string[];

  @IsString()
  @IsOptional()
  activationState?: string;

  @IsNumber()
  @IsOptional()
  priority?: number;

  @IsString()
  @IsOptional()
  fallbackProviderId?: string;
}

