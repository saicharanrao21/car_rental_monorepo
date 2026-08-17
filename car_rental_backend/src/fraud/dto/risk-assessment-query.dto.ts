import { IsOptional, IsString } from 'class-validator';

export class RiskAssessmentQueryDto {
  @IsOptional()
  @IsString()
  riskLevel?: string;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  startDate?: string;

  @IsOptional()
  @IsString()
  endDate?: string;

  @IsOptional()
  page?: number;

  @IsOptional()
  limit?: number;
}
