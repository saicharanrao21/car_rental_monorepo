import { IsDateString, IsNotEmpty, IsOptional, IsString, IsNumber, Min } from 'class-validator';

export class CreateHoldDto {
  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsNumber()
  @IsOptional()
  @Min(60)
  ttlSeconds?: number;

  @IsString()
  @IsOptional()
  idempotencyKey?: string;
}
