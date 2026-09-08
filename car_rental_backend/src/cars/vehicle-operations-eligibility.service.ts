import {
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisCacheService } from '../redis/redis-cache.service';
import { SystemConfigService } from '../config-engine/system-config.service';
import { REDIS_NAMESPACES, DEFAULT_CACHE_TTLS } from '../redis/redis-namespace.constants';
import {
  VehicleOperationalStatus,
  VehicleVerificationStatus,
  VerificationStatus,
  VendorDepositStatus,
  DocumentStatus,
  DocumentType,
} from '@prisma/client';
import { FleetOperationsRulesConfig } from '../config-engine/system-config.interface';

export interface VehicleEligibilityBlocker {
  code: string;
  message: string;
  severity: 'BLOCKER' | 'WARNING';
}

export interface VehicleEligibilityResult {
  eligible: boolean;
  carId: string;
  operationalStatus: VehicleOperationalStatus;
  verificationStatus: VehicleVerificationStatus;
  blockers: VehicleEligibilityBlocker[];
  requiredActions: string[];
  serviceAreaId?: string | null;
  serviceAreaName?: string | null;
  vendorId: string;
  vendorBusinessName: string;
  evaluatedAt: string;
}

@Injectable()
export class VehicleOperationsEligibilityService {
  private readonly logger = new Logger(VehicleOperationsEligibilityService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly cacheService?: RedisCacheService,
    @Optional() private readonly configService?: SystemConfigService,
  ) {}

  /**
   * Evaluates server-authoritative eligibility for a vehicle to be ACTIVE and customer-bookable.
   */
  async evaluateEligibility(
    carId: string,
    options?: { skipCache?: boolean },
  ): Promise<VehicleEligibilityResult> {
    const cacheKey = REDIS_NAMESPACES.CACHE.VEHICLE_ELIGIBILITY(carId);

    if (!options?.skipCache && this.cacheService) {
      const cached = await this.cacheService.get<VehicleEligibilityResult>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const car = await this.prisma.car.findUnique({
      where: { id: carId },
      include: {
        vendor: {
          include: {
            vendorSecurityDeposit: true,
          },
        },
        serviceArea: true,
        documents: true,
      },
    });

    if (!car) {
      throw new NotFoundException(`Vehicle with ID ${carId} not found.`);
    }

    const blockers: VehicleEligibilityBlocker[] = [];
    const requiredActions: string[] = [];

    // 1. Fetch dynamic platform fleet operational rules
    let config: FleetOperationsRulesConfig = {
      fleetActivationEnabled: true,
      requireVendorVerified: true,
      requireVendorSecurityDeposit: true,
      requireServiceAreaAssignment: true,
      requireVehicleVerification: true,
      maxMaintenanceDays: 90,
      autoDeactivateOnMissingCoverage: true,
      allowVendorSelfDeactivation: true,
      mandatoryVehicleDocuments: ['RC_BOOK', 'INSURANCE'],
      availabilityBufferMinutes: 120,
    };

    if (this.configService) {
      try {
        config = await this.configService.getFleetOperationsConfig();
      } catch (err) {
        this.logger.warn(`Could not load fleet operations config, using defaults: ${err?.message}`);
      }
    }

    // Check Rule 1: Platform-wide fleet activation toggle
    if (!config.fleetActivationEnabled) {
      blockers.push({
        code: 'PLATFORM_FLEET_ACTIVATION_DISABLED',
        message: 'Platform administrator has temporarily disabled vehicle activations.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Await platform administration reenabling vehicle activations.');
    }

    // Check Rule 2: Vendor Verification
    if (config.requireVendorVerified) {
      if (car.vendor.verificationStatus !== VerificationStatus.VERIFIED) {
        blockers.push({
          code: 'VENDOR_NOT_VERIFIED',
          message: `Vendor '${car.vendor.businessName}' verification status is ${car.vendor.verificationStatus}. Must be VERIFIED.`,
          severity: 'BLOCKER',
        });
        requiredActions.push('Complete vendor business onboarding verification with admin.');
      }
    }

    // Check Rule 3: Vendor Security Deposit
    if (config.requireVendorSecurityDeposit) {
      const deposit = car.vendor.vendorSecurityDeposit;
      if (!deposit) {
        blockers.push({
          code: 'VENDOR_DEPOSIT_MISSING',
          message: 'Vendor has not initialized their required platform security deposit.',
          severity: 'BLOCKER',
        });
        requiredActions.push('Pay or configure the mandatory vendor security deposit.');
      } else if (
        deposit.status === VendorDepositStatus.REQUIRED ||
        deposit.status === VendorDepositStatus.PENDING ||
        deposit.status === VendorDepositStatus.FORFEITED
      ) {
        blockers.push({
          code: 'VENDOR_DEPOSIT_UNPAID',
          message: `Vendor security deposit is in status '${deposit.status}'. Required deposit must be settled.`,
          severity: 'BLOCKER',
        });
        requiredActions.push('Settle outstanding vendor security deposit.');
      } else if (
        deposit.status === VendorDepositStatus.PARTIALLY_PAID &&
        Number(deposit.remainingAmount) > 0
      ) {
        blockers.push({
          code: 'VENDOR_DEPOSIT_PARTIAL',
          message: `Vendor has unpaid security deposit balance of INR ${deposit.remainingAmount}.`,
          severity: 'BLOCKER',
        });
        requiredActions.push('Pay remaining vendor security deposit balance.');
      }
    }

    // Check Rule 4: Service Area Assignment & Authorization
    if (config.requireServiceAreaAssignment) {
      if (!car.serviceAreaId) {
        blockers.push({
          code: 'SERVICE_AREA_NOT_ASSIGNED',
          message: 'Vehicle is not assigned to any operational service area.',
          severity: 'BLOCKER',
        });
        requiredActions.push('Assign vehicle to an authorized operational service area.');
      } else {
        // Verify that the vendor is actually authorized to operate in this service area
        const vendorAssignment = await this.prisma.vendorServiceArea.findUnique({
          where: {
            vendorId_serviceAreaId: {
              vendorId: car.vendorId,
              serviceAreaId: car.serviceAreaId,
            },
          },
        });

        if (!vendorAssignment || !vendorAssignment.isActive) {
          blockers.push({
            code: 'SERVICE_AREA_NOT_AUTHORIZED',
            message: `Vendor is not authorized or active in assigned service area '${car.serviceArea?.name || car.serviceAreaId}'.`,
            severity: 'BLOCKER',
          });
          requiredActions.push('Obtain active vendor service area coverage from platform operations.');
        }

        if (car.serviceArea && car.serviceArea.status !== 'ACTIVE') {
          blockers.push({
            code: 'SERVICE_AREA_INACTIVE',
            message: `Assigned service area '${car.serviceArea.name}' is currently ${car.serviceArea.status}.`,
            severity: 'BLOCKER',
          });
          requiredActions.push('Select an active service area.');
        }
      }
    }

    // Check Rule 5: Vehicle Verification
    if (config.requireVehicleVerification) {
      if (car.verificationStatus === VehicleVerificationStatus.PENDING) {
        blockers.push({
          code: 'VEHICLE_VERIFICATION_PENDING',
          message: 'Vehicle registration and documentation verification is pending review.',
          severity: 'BLOCKER',
        });
        requiredActions.push('Submit vehicle for admin verification review.');
      } else if (car.verificationStatus === VehicleVerificationStatus.REJECTED) {
        blockers.push({
          code: 'VEHICLE_VERIFICATION_REJECTED',
          message: `Vehicle verification was rejected: ${car.rejectionReason || 'No reason provided.'}`,
          severity: 'BLOCKER',
        });
        requiredActions.push('Address rejection reason and resubmit vehicle for verification.');
      }
    }

    // Check Rule 6: Current Operational State Blockers
    if (car.operationalStatus === VehicleOperationalStatus.MAINTENANCE) {
      blockers.push({
        code: 'VEHICLE_IN_MAINTENANCE',
        message: `Vehicle is currently under maintenance: ${car.maintenanceReason || 'Routine maintenance'}.`,
        severity: 'BLOCKER',
      });
      requiredActions.push('Complete scheduled maintenance before returning vehicle to active status.');
    } else if (car.operationalStatus === VehicleOperationalStatus.SUSPENDED) {
      blockers.push({
        code: 'VEHICLE_SUSPENDED',
        message: 'Vehicle has been administratively suspended from operations.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Contact platform administration to lift administrative suspension.');
    } else if (car.operationalStatus === VehicleOperationalStatus.RETIRED) {
      blockers.push({
        code: 'VEHICLE_RETIRED',
        message: 'Vehicle is permanently retired and decommissioned from the fleet.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Retired vehicles cannot be reactivated.');
    }

    // Check Rule 7: Vehicle Specifications & Metadata Completeness
    if (!car.registrationNumber || car.registrationNumber.trim() === '') {
      blockers.push({
        code: 'MISSING_REGISTRATION_NUMBER',
        message: 'Vehicle registration number is missing.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Provide a valid vehicle registration plate number.');
    }

    if (!car.photos || car.photos.length === 0) {
      blockers.push({
        code: 'MISSING_PHOTOS',
        message: 'Vehicle must have at least one photo.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Upload at least one exterior/interior photo of the vehicle.');
    }

    if (Number(car.pricePerDay) <= 0) {
      blockers.push({
        code: 'INVALID_PRICING',
        message: 'Vehicle daily pricing must be greater than zero.',
        severity: 'BLOCKER',
      });
      requiredActions.push('Set a valid daily rental rate.');
    }

    // Check Rule 8: Mandatory Vehicle Documents
    if (config.mandatoryVehicleDocuments && config.mandatoryVehicleDocuments.length > 0) {
      for (const requiredDocType of config.mandatoryVehicleDocuments) {
        const found = car.documents.find(
          (d) => d.type === requiredDocType && d.status !== DocumentStatus.REJECTED,
        );
        if (!found) {
          blockers.push({
            code: `MISSING_DOCUMENT_${requiredDocType}`,
            message: `Mandatory vehicle document '${requiredDocType}' is missing or rejected.`,
            severity: 'BLOCKER',
          });
          requiredActions.push(`Upload valid ${requiredDocType} document.`);
        }
      }
    }

    const eligible = blockers.filter((b) => b.severity === 'BLOCKER').length === 0;

    const result: VehicleEligibilityResult = {
      eligible,
      carId: car.id,
      operationalStatus: car.operationalStatus,
      verificationStatus: car.verificationStatus,
      blockers,
      requiredActions,
      serviceAreaId: car.serviceAreaId,
      serviceAreaName: car.serviceArea?.name || null,
      vendorId: car.vendorId,
      vendorBusinessName: car.vendor.businessName,
      evaluatedAt: new Date().toISOString(),
    };

    if (this.cacheService) {
      await this.cacheService.set(cacheKey, result, DEFAULT_CACHE_TTLS.MEDIUM_TERM);
    }

    return result;
  }

  /**
   * Invalidates Redis cache for vehicle eligibility.
   */
  async invalidateEligibilityCache(carId: string): Promise<void> {
    if (this.cacheService) {
      const cacheKey = REDIS_NAMESPACES.CACHE.VEHICLE_ELIGIBILITY(carId);
      await this.cacheService.delete(cacheKey);
    }
  }
}
