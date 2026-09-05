import { IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { VehicleBlockType } from '@prisma/client';

export class CreateBlockDto {
  @IsDateString()
  @IsNotEmpty()
  startDate: string;

  @IsDateString()
  @IsNotEmpty()
  endDate: string;

  @IsEnum(VehicleBlockType)
  @IsOptional()
  blockType?: VehicleBlockType;

  @IsString()
  @IsOptional()
  reason?: string;
}
