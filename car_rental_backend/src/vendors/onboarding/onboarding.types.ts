import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsBoolean,
  Min,
  Max,
  IsDateString,
  IsObject,
} from 'class-validator';
import {
  RequirementCategory,
  RequirementScope,
  RequirementFulfillmentStatus,
  VendorDepositStatus,
  VendorDepositTransactionType,
  LedgerDirection,
} from '@prisma/client';

export {
  RequirementCategory,
  RequirementScope,
  RequirementFulfillmentStatus,
  VendorDepositStatus,
  VendorDepositTransactionType,
  LedgerDirection,
};

export type OnboardingEligibilityState =
  | 'ELIGIBLE'
  | 'INCOMPLETE'
  | 'UNDER_REVIEW'
  | 'BLOCKED';

export class CreateRequirementDefinitionDto {
  @IsString()
  @IsNotEmpty()
  code: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsEnum(RequirementCategory)
  @IsNotEmpty()
  category: RequirementCategory;

  @IsBoolean()
  @IsOptional()
  isRequired?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsNumber()
  @IsOptional()
  displayOrder?: number;

  @IsEnum(RequirementScope)
  @IsOptional()
  scope?: RequirementScope;

  @IsString()
  @IsOptional()
  targetScopeValue?: string;

  @IsDateString()
  @IsOptional()
  effectiveFrom?: string;

  @IsDateString()
  @IsOptional()
  effectiveTo?: string;

  @IsObject()
  @IsOptional()
  config?: Record<string, any>;
}

export class UpdateRequirementDefinitionDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  isRequired?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsNumber()
  @IsOptional()
  displayOrder?: number;

  @IsEnum(RequirementScope)
  @IsOptional()
  scope?: RequirementScope;

  @IsString()
  @IsOptional()
  targetScopeValue?: string;

  @IsDateString()
  @IsOptional()
  effectiveFrom?: string;

  @IsDateString()
  @IsOptional()
  effectiveTo?: string;

  @IsObject()
  @IsOptional()
  config?: Record<string, any>;

  /**
   * If true, creates a new version instead of mutating in-place,
   * archiving the previous version by setting its effectiveTo to now.
   */
  @IsBoolean()
  @IsOptional()
  createNewVersion?: boolean;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class SubmitRequirementDto {
  @IsString()
  @IsOptional()
  documentId?: string;

  @IsString()
  @IsOptional()
  documentNumber?: string;

  @IsDateString()
  @IsOptional()
  issuedAt?: string;

  @IsDateString()
  @IsOptional()
  expiresAt?: string;

  @IsObject()
  @IsOptional()
  submissionData?: Record<string, any>;
}

export class ReviewRequirementDto {
  @IsEnum(RequirementFulfillmentStatus)
  @IsNotEmpty()
  status: RequirementFulfillmentStatus; // typically APPROVED or REJECTED

  @IsString()
  @IsOptional()
  rejectionReason?: string;

  @IsDateString()
  @IsOptional()
  expiresAt?: string;
}

export class WaiveRequirementDto {
  @IsString()
  @IsNotEmpty()
  reason: string;
}

export class RecordDepositPaymentDto {
  @IsNumber()
  @Min(1)
  amount: number;

  @IsString()
  @IsNotEmpty()
  paymentMethod: string; // e.g. "ONLINE_RAZORPAY", "BANK_TRANSFER", "CHEQUE", "NEFT_RTGS", "ADMIN_RECORDED"

  @IsString()
  @IsNotEmpty()
  reference: string; // payment ID or bank UTR

  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;

  @IsString()
  @IsOptional()
  reason?: string;

  @IsObject()
  @IsOptional()
  metadata?: Record<string, any>;
}

export class ReleaseDepositDto {
  @IsString()
  @IsNotEmpty()
  reference: string;

  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;

  @IsString()
  @IsNotEmpty()
  reason: string;
}

export class RefundDepositDto {
  @IsNumber()
  @Min(1)
  @IsOptional()
  amount?: number; // if omitted, refunds remaining paid balance

  @IsString()
  @IsNotEmpty()
  reference: string;

  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;

  @IsString()
  @IsNotEmpty()
  reason: string;
}

export class ForfeitDepositDto {
  @IsNumber()
  @Min(1)
  @IsOptional()
  amount?: number;

  @IsString()
  @IsNotEmpty()
  reason: string;

  @IsString()
  @IsNotEmpty()
  idempotencyKey: string;

  @IsString()
  @IsNotEmpty()
  reference: string;
}

export class AdjustDepositDto {
  @IsNumber()
  amount: number;

  @IsEnum(LedgerDirection)
  @IsOptional()
  direction?: LedgerDirection;

  @IsString()
  @IsNotEmpty()
  reason: string;

  @IsString()
  @IsOptional()
  reference?: string;

  @IsString()
  @IsOptional()
  idempotencyKey?: string;

  @IsNumber()
  @IsOptional()
  newRequiredAmount?: number;
}

export class HoldDepositDto {
  @IsString()
  @IsOptional()
  reason?: string;
}

export interface VendorRequirementItem {
  id: string;
  requirementDefinitionId: string;
  code: string;
  name: string;
  description: string | null;
  category: RequirementCategory;
  isRequired: boolean;
  scope: RequirementScope;
  status: RequirementFulfillmentStatus;
  documentId: string | null;
  documentNumber: string | null;
  issuedAt: Date | null;
  expiresAt: Date | null;
  isExpired: boolean;
  submissionData: any;
  submittedAt: Date | null;
  rejectionReason: string | null;
  reviewedByUserId: string | null;
  reviewedAt: Date | null;
  waivedByUserId: string | null;
  waivedReason: string | null;
  waiverReason?: string | null;
  waivedAt: Date | null;
  config: any;
  definition?: any;
}

export interface VendorDepositSummary {
  depositId: string | null;
  requiredAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: VendorDepositStatus;
  isSatisfied: boolean;
}

export interface VendorEligibilitySummary {
  totalRequirements: number;
  approvedCount: number;
  pendingCount: number;
  underReviewCount: number;
  rejectedCount: number;
  waivedCount: number;
  expiredCount: number;
}

export interface VendorEligibilityResult {
  vendorId: string;
  isEligible: boolean;
  eligibilityState: OnboardingEligibilityState;
  summary: VendorEligibilitySummary;
  depositSummary: VendorDepositSummary;
  requirements: VendorRequirementItem[];
  blockingReasons: string[];
  evaluatedAt: Date;
}
