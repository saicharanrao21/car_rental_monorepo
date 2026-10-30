import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsBoolean,
  IsArray,
} from 'class-validator';

export enum CollateralType {
  MONETARY_ONLINE = 'MONETARY_ONLINE',
  PHYSICAL_VEHICLE = 'PHYSICAL_VEHICLE',
  ORIGINAL_DOCUMENT = 'ORIGINAL_DOCUMENT',
  DIGILOCKER_HIGH_TRUST = 'DIGILOCKER_HIGH_TRUST',
}

export class RecordCollateralDto {
  @IsEnum(CollateralType)
  @IsNotEmpty()
  collateralType: CollateralType;

  // For PHYSICAL_VEHICLE
  @IsOptional()
  @IsString()
  vehicleRegistrationNumber?: string;

  @IsOptional()
  @IsString()
  vehicleMake?: string;

  @IsOptional()
  @IsString()
  vehicleModel?: string;

  @IsOptional()
  @IsString()
  yardSlotNumber?: string;

  @IsOptional()
  @IsBoolean()
  keysCollected?: boolean;

  // For ORIGINAL_DOCUMENT
  @IsOptional()
  @IsString()
  documentType?: string; // e.g., 'PASSPORT', 'VOTER_ID', 'AADHAAR_PHYSICAL'

  @IsOptional()
  @IsString()
  documentNumberMasked?: string;

  @IsOptional()
  @IsString()
  vaultLockerNumber?: string;

  @IsOptional()
  @IsBoolean()
  verifiedPhysically?: boolean;

  // General notes & physical proof URLs
  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsArray()
  photoUrls?: string[];
}

