import { IsNotEmpty, IsNumberString, IsOptional, IsString } from 'class-validator';

export class DistanceQueryDto {
  @IsNumberString()
  @IsNotEmpty()
  originLat: string;

  @IsNumberString()
  @IsNotEmpty()
  originLng: string;

  @IsNumberString()
  @IsNotEmpty()
  destLat: string;

  @IsNumberString()
  @IsNotEmpty()
  destLng: string;

  @IsOptional()
  @IsString()
  mode?: string; // 'driving', 'transit', etc.
}
