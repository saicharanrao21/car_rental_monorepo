import { BaseProvider } from './provider.interface';

export enum VerificationCapability {
  DRIVING_LICENCE_VERIFY = 'DRIVING_LICENCE_VERIFY',
  AADHAAR_VERIFY = 'AADHAAR_VERIFY',
  PAN_VERIFY = 'PAN_VERIFY',
  VEHICLE_RC_VERIFY = 'VEHICLE_RC_VERIFY',
  OCR_EXTRACT = 'OCR_EXTRACT',
}

export interface DrivingLicenceVerifyRequest {
  licenceNumber: string;
  dob?: string; // YYYY-MM-DD
  fullName?: string;
  frontImageUrl?: string;
  backImageUrl?: string;
}

export interface DrivingLicenceVerifyResponse {
  isValid: boolean;
  licenceNumber: string;
  holderName?: string;
  expiryDate?: Date;
  issueDate?: Date;
  vehicleClasses?: string[];
  status: 'VERIFIED' | 'REJECTED' | 'MANUAL_REVIEW_REQUIRED';
  rawResponse?: any;
}

export interface VehicleRcVerifyRequest {
  registrationNumber: string;
}

export interface VehicleRcVerifyResponse {
  isValid: boolean;
  registrationNumber: string;
  ownerName?: string;
  makerModel?: string;
  fuelType?: string;
  manufacturingDate?: string;
  insuranceValidUntil?: Date;
  fitnessValidUntil?: Date;
  status: 'VERIFIED' | 'REJECTED';
  rawResponse?: any;
}

export interface IdentityVerificationProvider extends BaseProvider {
  verifyDrivingLicence(req: DrivingLicenceVerifyRequest): Promise<DrivingLicenceVerifyResponse>;
  verifyVehicleRc(req: VehicleRcVerifyRequest): Promise<VehicleRcVerifyResponse>;
}
