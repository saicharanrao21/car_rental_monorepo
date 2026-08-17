import { IsEnum, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export enum RiskResolutionStatus {
  RESOLVED = 'RESOLVED',
  DISMISSED = 'DISMISSED',
  ESCALATED = 'ESCALATED',
}

export class ResolveRiskAssessmentDto {
  @IsEnum(RiskResolutionStatus)
  @IsNotEmpty()
  status: RiskResolutionStatus;

  @IsString()
  @IsNotEmpty()
  @MinLength(5, { message: 'Admin notes must be at least 5 characters long' })
  adminNotes: string;
}
