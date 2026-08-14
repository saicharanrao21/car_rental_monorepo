import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MinLength,
} from 'class-validator';

export enum ClaimDecision {
  APPROVED = 'APPROVED',
  PARTIALLY_APPROVED = 'PARTIALLY_APPROVED',
  REJECTED = 'REJECTED',
}

export class AdjudicateClaimDto {
  @IsEnum(ClaimDecision)
  decision: ClaimDecision;

  @IsNumber()
  @IsPositive()
  @IsOptional()
  approvedAmount?: number;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  adminNotes: string;
}
