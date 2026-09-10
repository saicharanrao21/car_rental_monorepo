import { IsString, IsNotEmpty, IsOptional, IsNumber, IsBoolean, Min, Max } from 'class-validator';

export class CreateCorporateAccountDto {
  @IsString()
  @IsNotEmpty()
  companyName!: string;

  @IsString()
  @IsNotEmpty()
  corporateCode!: string;

  @IsString()
  @IsNotEmpty()
  contactEmail!: string;

  @IsString()
  @IsNotEmpty()
  contactPhone!: string;

  @IsString()
  @IsOptional()
  taxIdNumber?: string;

  @IsString()
  @IsNotEmpty()
  billingAddress!: string;

  @IsNumber()
  @IsOptional()
  @Min(0)
  creditLimit?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  negotiatedDiscountPct?: number;

  @IsNumber()
  @IsOptional()
  paymentTermsDays?: number;

  @IsString()
  @IsOptional()
  preferredVendorId?: string;

  @IsOptional()
  metadata?: Record<string, any>;
}

export class UpdateCorporateAccountDto {
  @IsString()
  @IsOptional()
  companyName?: string;

  @IsString()
  @IsOptional()
  contactEmail?: string;

  @IsString()
  @IsOptional()
  contactPhone?: string;

  @IsString()
  @IsOptional()
  taxIdNumber?: string;

  @IsString()
  @IsOptional()
  billingAddress?: string;

  @IsNumber()
  @IsOptional()
  @Min(0)
  creditLimit?: number;

  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(100)
  negotiatedDiscountPct?: number;

  @IsNumber()
  @IsOptional()
  paymentTermsDays?: number;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsString()
  @IsOptional()
  preferredVendorId?: string;

  @IsOptional()
  metadata?: Record<string, any>;
}

export class ValidateCorporateCreditDto {
  @IsString()
  @IsNotEmpty()
  corporateCode!: string;

  @IsNumber()
  @Min(0)
  estimatedAmount!: number;
}

export class AddCorporateEmployeeDto {
  @IsString()
  @IsNotEmpty()
  userId!: string;

  @IsString()
  @IsOptional()
  employeeCode?: string;

  @IsString()
  @IsOptional()
  department?: string;

  @IsNumber()
  @IsOptional()
  @Min(0)
  spendingLimitMonthly?: number;
}

export class UpdateCorporateEmployeeStatusDto {
  @IsBoolean()
  isActive!: boolean;
}

