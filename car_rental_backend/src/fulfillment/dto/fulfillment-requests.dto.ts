import { IsString, IsNotEmpty, IsOptional, IsNumber, IsEnum, IsBoolean, Min, Max } from 'class-validator';
import { SubstitutionDecision, SubstitutionReason } from '@prisma/client';

export class StartPreparationDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsString()
  @IsOptional()
  assignedStaffId?: string;

  @IsString()
  @IsOptional()
  notes?: string;
}

export class MarkCleanedDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsString()
  @IsOptional()
  assignedStaffId?: string;

  @IsOptional()
  cleaningChecklist?: string[];
}

export class MarkInspectedDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsString()
  @IsOptional()
  assignedStaffId?: string;

  @IsString()
  @IsOptional()
  inspectionNotes?: string;

  @IsNumber()
  @IsOptional()
  @Min(0)
  odometerReading?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  fuelPercent?: number;
}

export class MarkReadyForPickupDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsString()
  @IsOptional()
  bayNumber?: string;

  @IsString()
  @IsOptional()
  keyLocation?: string;
}

export class CustomerArrivalDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsString()
  @IsOptional()
  deskNumber?: string;

  @IsBoolean()
  @IsOptional()
  verifiedIdentity?: boolean;

  @IsString()
  @IsOptional()
  notes?: string;
}

export class EvaluateSubstitutionDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsEnum(SubstitutionReason)
  @IsNotEmpty()
  reason!: SubstitutionReason;

  @IsString()
  @IsOptional()
  reasonDetails?: string;
}

export class ExecuteSubstitutionDto {
  @IsString()
  @IsNotEmpty()
  bookingId!: string;

  @IsEnum(SubstitutionDecision)
  @IsNotEmpty()
  decision!: SubstitutionDecision;

  @IsEnum(SubstitutionReason)
  @IsNotEmpty()
  reason!: SubstitutionReason;

  @IsString()
  @IsOptional()
  reasonDetails?: string;

  @IsString()
  @IsOptional()
  targetCarId?: string;

  @IsBoolean()
  @IsOptional()
  waivePriceDifference?: boolean;

  @IsBoolean()
  @IsOptional()
  customerApproved?: boolean;
}
