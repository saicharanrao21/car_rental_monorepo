import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FleetLifecycleService } from './fleet-lifecycle.service';
import {
  ComplianceDocumentType,
  ComplianceStatus,
  FleetOperationalState,
  VehicleComplianceRecord,
} from './fleet-domain.types';

export class RegisterComplianceDocumentDto {
  carId!: string;
  documentType!: ComplianceDocumentType;
  documentNumber!: string;
  issuingAuthority?: string;
  issueDate!: string;
  expiryDate!: string;
  documentUrl?: string;
  isMandatoryForRental?: boolean;
}

export interface ComplianceAuditReport {
  carId: string;
  overallComplianceStatus: ComplianceStatus;
  isRentalCompliant: boolean;
  activeDocuments: VehicleComplianceRecord[];
  expiringSoonDocuments: VehicleComplianceRecord[];
  expiredDocuments: VehicleComplianceRecord[];
  blockingReasons: string[];
}

@Injectable()
export class FleetComplianceService {
  private readonly logger = new Logger(FleetComplianceService.name);

  // In-memory compliance documents store (keyed by carId)
  private readonly complianceStore: Map<string, VehicleComplianceRecord[]> = new Map();

  constructor(
    private readonly prisma: PrismaService,
    private readonly lifecycleService: FleetLifecycleService,
  ) {}

  /**
   * Registers a compliance document for a vehicle and calculates expiry window.
   */
  async registerDocument(dto: RegisterComplianceDocumentDto): Promise<VehicleComplianceRecord> {
    if (!dto.carId || !dto.documentNumber || !dto.expiryDate) {
      throw new BadRequestException('carId, documentNumber and expiryDate are required.');
    }

    const expiry = new Date(dto.expiryDate);
    const now = new Date();
    const daysUntilExpiry = Math.ceil((expiry.getTime() - now.getTime()) / (1000 * 3600 * 24));

    let status = ComplianceStatus.VALID;
    if (daysUntilExpiry <= 0) {
      status = ComplianceStatus.EXPIRED;
    } else if (daysUntilExpiry <= 30) {
      status = ComplianceStatus.EXPIRING_SOON;
    }

    const record: VehicleComplianceRecord = {
      id: `doc_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
      carId: dto.carId,
      documentType: dto.documentType,
      documentNumber: dto.documentNumber,
      issuingAuthority: dto.issuingAuthority || 'Regional Transport Office (RTO)',
      issueDate: dto.issueDate || new Date().toISOString(),
      expiryDate: dto.expiryDate,
      documentUrl: dto.documentUrl,
      status,
      daysUntilExpiry,
      isMandatoryForRental: dto.isMandatoryForRental ?? true,
      verifiedAt: new Date().toISOString(),
      verifiedBy: 'Fleet Compliance Engine',
    };

    const existing = this.complianceStore.get(dto.carId) || [];
    // Replace if document of same type exists
    const filtered = existing.filter((d) => d.documentType !== dto.documentType);
    filtered.push(record);
    this.complianceStore.set(dto.carId, filtered);

    // If an essential document is registered as expired, trigger compliance blocking
    if (status === ComplianceStatus.EXPIRED && record.isMandatoryForRental) {
      await this.triggerComplianceBlock(dto.carId, `Mandatory ${dto.documentType} expired on ${dto.expiryDate}`);
    }

    this.logger.log(
      `[FLEET_COMPLIANCE] Registered ${dto.documentType} #${dto.documentNumber} for vehicle ${dto.carId}. Status: ${status} (${daysUntilExpiry} days left)`,
    );

    return record;
  }

  /**
   * Evaluates overall compliance for a vehicle and checks all rental mandates.
   */
  async evaluateVehicleCompliance(carId: string): Promise<ComplianceAuditReport> {
    const docs = this.complianceStore.get(carId) || [];
    const now = new Date();

    const activeDocs: VehicleComplianceRecord[] = [];
    const expiringSoonDocs: VehicleComplianceRecord[] = [];
    const expiredDocs: VehicleComplianceRecord[] = [];
    const blockingReasons: string[] = [];

    // Re-verify days until expiry dynamically
    for (const doc of docs) {
      const expiry = new Date(doc.expiryDate);
      const daysUntilExpiry = Math.ceil((expiry.getTime() - now.getTime()) / (1000 * 3600 * 24));
      doc.daysUntilExpiry = daysUntilExpiry;

      if (daysUntilExpiry <= 0) {
        doc.status = ComplianceStatus.EXPIRED;
        expiredDocs.push(doc);
        if (doc.isMandatoryForRental) {
          blockingReasons.push(`Mandatory document ${doc.documentType} expired ${Math.abs(daysUntilExpiry)} days ago.`);
        }
      } else if (daysUntilExpiry <= 30) {
        doc.status = ComplianceStatus.EXPIRING_SOON;
        expiringSoonDocs.push(doc);
        activeDocs.push(doc);
      } else {
        doc.status = ComplianceStatus.VALID;
        activeDocs.push(doc);
      }
    }

    let overallComplianceStatus = ComplianceStatus.VALID;
    if (expiredDocs.length > 0) {
      overallComplianceStatus = ComplianceStatus.EXPIRED;
    } else if (expiringSoonDocs.length > 0) {
      overallComplianceStatus = ComplianceStatus.EXPIRING_SOON;
    }

    const isRentalCompliant = blockingReasons.length === 0;

    // Auto-block vehicle if mandatory document expired
    if (!isRentalCompliant) {
      await this.triggerComplianceBlock(carId, blockingReasons.join('; '));
    }

    return {
      carId,
      overallComplianceStatus,
      isRentalCompliant,
      activeDocuments: activeDocs,
      expiringSoonDocuments: expiringSoonDocs,
      expiredDocuments: expiredDocs,
      blockingReasons,
    };
  }

  /**
   * Automatically transitions a vehicle to COMPLIANCE_BLOCKED if an active violation occurs.
   */
  private async triggerComplianceBlock(carId: string, reason: string) {
    try {
      const currentState = await this.lifecycleService.getVehicleState(carId);
      if (currentState !== FleetOperationalState.COMPLIANCE_BLOCKED && currentState !== FleetOperationalState.RETIRED && currentState !== FleetOperationalState.SOLD) {
        await this.lifecycleService.transitionState(
          carId,
          FleetOperationalState.COMPLIANCE_BLOCKED,
          { id: 'compliance_daemon', role: 'SYSTEM' },
          { reason, skipPrerequisitesCheck: true },
        );
      }
    } catch (err: any) {
      this.logger.warn(`Could not trigger compliance block on vehicle ${carId}: ${err.message}`);
    }
  }

  /**
   * Retrieves all registered compliance documents for a vehicle.
   */
  async getDocuments(carId: string): Promise<VehicleComplianceRecord[]> {
    return this.complianceStore.get(carId) || [];
  }
}
