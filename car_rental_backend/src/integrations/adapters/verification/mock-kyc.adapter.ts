import { Injectable } from '@nestjs/common';
import {
  IdentityVerificationProvider,
  VerificationCapability,
  DrivingLicenceVerifyRequest,
  DrivingLicenceVerifyResponse,
  VehicleRcVerifyRequest,
  VehicleRcVerifyResponse,
} from '../../contracts/verification-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockKycAdapter implements IdentityVerificationProvider {
  getProviderId(): string {
    return 'mock_kyc';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.IDENTITY_VERIFICATION;
  }

  getDisplayName(): string {
    return 'Mock Identity Verification Provider';
  }

  getSupportedCapabilities(): string[] {
    return [
      VerificationCapability.DRIVING_LICENCE_VERIFY,
      VerificationCapability.VEHICLE_RC_VERIFY,
      VerificationCapability.OCR_EXTRACT,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 3000;
  }

  async verifyDrivingLicence(req: DrivingLicenceVerifyRequest): Promise<DrivingLicenceVerifyResponse> {
    const isMockValid = req.licenceNumber !== 'INVALID_LICENCE';
    return {
      isValid: isMockValid,
      licenceNumber: req.licenceNumber,
      holderName: req.fullName || 'Mock Driver',
      expiryDate: new Date(Date.now() + 365 * 24 * 3600 * 1000 * 5),
      status: isMockValid ? 'VERIFIED' : 'REJECTED',
    };
  }

  async verifyVehicleRc(req: VehicleRcVerifyRequest): Promise<VehicleRcVerifyResponse> {
    const isMockValid = req.registrationNumber !== 'INVALID_RC';
    return {
      isValid: isMockValid,
      registrationNumber: req.registrationNumber,
      ownerName: 'Mock Fleet Owner',
      makerModel: 'Maruti Swift',
      status: isMockValid ? 'VERIFIED' : 'REJECTED',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Verification Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock verification test connection successful',
    };
  }
}
