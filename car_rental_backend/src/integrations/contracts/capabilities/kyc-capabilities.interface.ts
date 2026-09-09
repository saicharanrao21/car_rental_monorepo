export enum KycCapability {
  PAN_VERIFICATION = 'PAN_VERIFICATION',
  AADHAAR_VERIFICATION = 'AADHAAR_VERIFICATION',
  DRIVING_LICENCE_VERIFICATION = 'DRIVING_LICENCE_VERIFICATION',
  VEHICLE_RC_VERIFICATION = 'VEHICLE_RC_VERIFICATION',
  BANK_VERIFICATION = 'BANK_VERIFICATION',
  SELFIE_VERIFICATION = 'SELFIE_VERIFICATION',
  FACE_MATCH = 'FACE_MATCH',
  LIVENESS = 'LIVENESS',
  OCR = 'OCR',
  DOCUMENT_EXTRACTION = 'DOCUMENT_EXTRACTION',
  BUSINESS_VERIFICATION = 'BUSINESS_VERIFICATION',
}

export interface PanVerificationPayload {
  panNumber: string;
  fullName?: string;
  dateOfBirth?: string;
}

export interface AadhaarVerificationPayload {
  aadhaarNumber: string;
  otp?: string;
  consent?: boolean;
}

export interface DlVerificationPayload {
  dlNumber: string;
  dateOfBirth: string;
}

export interface RcVerificationPayload {
  vehicleRegistrationNumber: string;
  chassisNumberLast5?: string;
}

export interface FaceMatchPayload {
  sourceImageUrl: string;
  targetImageUrl: string;
}

export interface OcrExtractionPayload {
  documentImageUrl: string;
  documentType: 'PAN' | 'AADHAAR' | 'DRIVING_LICENCE' | 'RC' | 'PASSPORT' | 'VOTER_ID';
}

export interface VerificationResult {
  verified: boolean;
  referenceId: string;
  documentType: string;
  extractedData?: Record<string, any>;
  confidenceScore?: number;
  matchScore?: number;
  isLivenessDetected?: boolean;
  status: 'VERIFIED' | 'REJECTED' | 'MANUAL_REVIEW_REQUIRED' | 'PENDING';
  rejectionReason?: string;
  provider: string;
  timestamp: Date;
}
