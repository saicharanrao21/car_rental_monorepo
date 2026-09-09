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
