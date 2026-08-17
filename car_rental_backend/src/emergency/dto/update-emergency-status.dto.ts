import { IsEnum, IsInt, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { EmergencyStatus } from '@prisma/client';

export class UpdateEmergencyStatusDto {
  @IsEnum(EmergencyStatus)
  @IsNotEmpty()
  status: EmergencyStatus;

  @IsString()
  @IsOptional()
  assignedProviderName?: string;

  @IsString()
  @IsOptional()
  assignedProviderPhone?: string;

  @IsString()
  @IsOptional()
  contactNotes?: string;

  @IsString()
  @IsOptional()
  resolutionNotes?: string;

  @IsInt()
  @IsOptional()
  estimatedEtaMinutes?: number;
}
