import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MinLength,
} from 'class-validator';

export class CreateDamageClaimDto {
  @IsNumber()
  @IsPositive()
  claimedAmount: number;

  @IsString()
  @IsNotEmpty()
  @MinLength(10)
  description: string;

  @IsArray()
  @IsString({ each: true })
  damagePhotos: string[];

  @IsString()
  @IsOptional()
  vendorNotes?: string;
}
