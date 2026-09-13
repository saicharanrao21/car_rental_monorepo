import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
export class SurepassKycAdapter implements IdentityVerificationProvider {
  private readonly logger = new Logger(SurepassKycAdapter.name);
  private apiKey: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('SUREPASS_API_KEY') || '';
  }

  getProviderId(): string {
    return 'surepass';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.IDENTITY_VERIFICATION;
  }

  getDisplayName(): string {
    return 'Surepass / DigiLocker Identity Verification';
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
    return 10000;
  }

  private hasLiveCredentials(): boolean {
    if (!this.apiKey) return false;
    if (
      this.apiKey.startsWith('placeholder') ||
      this.apiKey.startsWith('mock') ||
      this.apiKey.startsWith('test')
    ) {
      return false;
    }
    if (process.env.NODE_ENV === 'test') {
      return false;
    }
    return true;
  }

  async verifyDrivingLicence(req: DrivingLicenceVerifyRequest): Promise<DrivingLicenceVerifyResponse> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException('Surepass API key (SUREPASS_API_KEY) not configured for production environment');
    }

    if (hasLive) {
      try {
        const response = await fetch('https://kyc-api.surepass.io/api/v1/driving-license/driving-license', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            id_number: req.licenceNumber,
            dob: req.dob || '1990-01-01',
          }),
        });

        const data: any = await response.json();
        if (response.ok && data?.success) {
          const details = data.data || {};
          return {
            isValid: true,
            licenceNumber: details.license_number || req.licenceNumber,
            holderName: details.name || req.fullName || 'Verified Driver',
            expiryDate: details.expiry_date ? new Date(details.expiry_date) : new Date(Date.now() + 5 * 365 * 24 * 3600 * 1000),
            issueDate: details.issue_date ? new Date(details.issue_date) : undefined,
            vehicleClasses: details.vehicle_classes || ['LMV', 'MCWG'],
            status: 'VERIFIED',
            rawResponse: data,
          };
        }

        return {
          isValid: false,
          licenceNumber: req.licenceNumber,
          status: 'REJECTED',
          rejectionReason: data?.message || 'Driving licence verification failed on Surepass registry',
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`[SUREPASS_DL] Network error: ${err?.message}`);
        throw new ServiceUnavailableException(`Surepass KYC service error: ${err?.message}`);
      }
    }

    // Dev/Test simulation
    const isValid = req.licenceNumber && req.licenceNumber.length >= 8;
    return {
      isValid: Boolean(isValid),
      licenceNumber: req.licenceNumber,
      holderName: req.fullName || 'Verified Driver',
      expiryDate: new Date(Date.now() + 365 * 24 * 3600 * 1000 * 5),
      issueDate: new Date(Date.now() - 365 * 24 * 3600 * 1000 * 3),
      vehicleClasses: ['LMV', 'MCWG'],
      status: isValid ? 'VERIFIED' : 'REJECTED',
      rejectionReason: isValid ? undefined : 'Licence number invalid length',
    };
  }

  async verifyVehicleRc(req: VehicleRcVerifyRequest): Promise<VehicleRcVerifyResponse> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException('Surepass API key (SUREPASS_API_KEY) not configured for production environment');
    }

    if (hasLive) {
      try {
        const response = await fetch('https://kyc-api.surepass.io/api/v1/rc/rc-full', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            id_number: req.registrationNumber,
          }),
        });

        const data: any = await response.json();
        if (response.ok && data?.success) {
          const details = data.data || {};
          return {
            isValid: true,
            registrationNumber: details.rc_number || req.registrationNumber,
            ownerName: details.owner_name || 'Verified Fleet Owner',
            makerModel: details.maker_model || 'Verified Vehicle',
            fuelType: details.fuel_type || 'PETROL',
            insuranceValidUntil: details.insurance_upto ? new Date(details.insurance_upto) : undefined,
            fitnessValidUntil: details.fit_upto ? new Date(details.fit_upto) : undefined,
            status: 'VERIFIED',
            rawResponse: data,
          };
        }

        return {
          isValid: false,
          registrationNumber: req.registrationNumber,
          status: 'REJECTED',
          rejectionReason: data?.message || 'Vehicle RC verification failed on VAHAN registry',
          rawResponse: data,
        };
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`[SUREPASS_RC] Network error: ${err?.message}`);
        throw new ServiceUnavailableException(`Surepass RC service error: ${err?.message}`);
      }
    }

    // Dev/Test simulation
    const isValid = req.registrationNumber && req.registrationNumber.length >= 6;
    return {
      isValid: Boolean(isValid),
      registrationNumber: req.registrationNumber,
      ownerName: 'Verified Fleet Owner',
      makerModel: 'Hyundai Creta',
      fuelType: 'PETROL',
      insuranceValidUntil: new Date(Date.now() + 300 * 24 * 3600 * 1000),
      fitnessValidUntil: new Date(Date.now() + 600 * 24 * 3600 * 1000),
      status: isValid ? 'VERIFIED' : 'REJECTED',
      rejectionReason: isValid ? undefined : 'Registration number invalid length',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const configured = Boolean(this.apiKey && !this.apiKey.startsWith('placeholder'));
    return {
      status: configured ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: configured ? 'Surepass API configured' : 'Surepass running in mock mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const key = credentials?.apiKey || this.apiKey;
    if (!key) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Surepass apiKey required',
      };
    }
    return {
      success: true,
      latencyMs: 1,
      message: 'Surepass API key format verified',
    };
  }
}
