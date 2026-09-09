import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class ResolveIncidentDto {
  @IsString()
  @IsNotEmpty()
  resolutionNotes!: string;
}

export class RebalancingActionDto {
  @IsString()
  @IsOptional()
  notes?: string;
}
