import { IsNotEmpty, IsNumberString, IsOptional, IsString } from 'class-validator';

export class ForwardGeocodeQueryDto {
  @IsString()
  @IsNotEmpty()
  address: string;
}

export class ReverseGeocodeQueryDto {
  @IsNumberString()
  @IsNotEmpty()
  lat: string;

  @IsNumberString()
  @IsNotEmpty()
  lng: string;
}
