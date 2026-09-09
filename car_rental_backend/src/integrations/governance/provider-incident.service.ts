import { Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IntegrationCategory } from '../registry/provider.types';
import {
  CreateIncidentDto,
  DetectionSource,
  IncidentFilterQuery,
  IncidentSeverity,
  IncidentStatus,
  IncidentType,
  ProviderIncidentRecord,
  UpdateIncidentDto,
} from './provider-incident.types';

@Injectable()
export class ProviderIncidentService {
  private readonly logger = new Logger(ProviderIncidentService.name);

  // In-memory incidents storage for low latency & test environment resilience
  private readonly memoryIncidents = new Map<string, ProviderIncidentRecord>();

  constructor(@Optional() private readonly prisma?: PrismaService) {}

  /**
   * Create a new incident record or update an existing active incident for this provider.
   */
  public async createIncident(dto: CreateIncidentDto): Promise<ProviderIncidentRecord> {
    const providerKey = dto.providerId.toLowerCase();

    // Check if an active incident already exists for this provider and incident type
    const existingActive = Array.from(this.memoryIncidents.values()).find(
      (inc) =>
        inc.providerId.toLowerCase() === providerKey &&
        inc.incidentType === dto.incidentType &&
        inc.status !== IncidentStatus.RESOLVED,
    );

    if (existingActive) {
      existingActive.failureCount += 1;
      existingActive.updatedAt = new Date();
      if (dto.reason) {
        existingActive.reason = `${existingActive.reason || ''} | ${dto.reason}`;
      }
      if (dto.circuitState) {
        existingActive.circuitState = dto.circuitState;
      }
      this.logger.warn(
        `[INCIDENT_ESCALATED] Existing active incident [${existingActive.id}] for provider [${dto.providerId}] updated. Failures: ${existingActive.failureCount}`,
      );
      await this.persistIncident(existingActive, false);
      return existingActive;
    }

    const id = `inc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const newRecord: ProviderIncidentRecord = {
      id,
      providerId: dto.providerId,
      category: dto.category,
      title: dto.title,
      status: IncidentStatus.DETECTED,
      severity: dto.severity,
      incidentType: dto.incidentType,
      detectionSource: dto.detectionSource,
      circuitState: dto.circuitState || 'CLOSED',
      failureCount: 1,
      startedAt: new Date(),
      reason: dto.reason,
      metadata: dto.metadata || {},
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.memoryIncidents.set(id, newRecord);
    this.logger.warn(
      `[INCIDENT_CREATED] Incident [${id}] created for provider [${dto.providerId}]: ${dto.title} (${dto.severity})`,
    );

    await this.persistIncident(newRecord, true);
    return newRecord;
  }

  /**
   * Automatically triggered by Circuit Breaker or Runtime when a threshold is breached.
   */
  public async autoDetectIncident(
    providerId: string,
    category: IntegrationCategory,
    incidentType: IncidentType,
    severity: IncidentSeverity,
    reason: string,
    circuitState?: string,
  ): Promise<ProviderIncidentRecord> {
    return this.createIncident({
      providerId,
      category,
      title: `Automated Incident: ${incidentType} detected on ${providerId}`,
      severity,
      incidentType,
      detectionSource: DetectionSource.CIRCUIT_BREAKER,
      reason,
      circuitState,
    });
  }

  /**
   * Update an incident's status, notes, or severity.
   */
  public async updateIncident(id: string, dto: UpdateIncidentDto): Promise<ProviderIncidentRecord> {
    const record = this.memoryIncidents.get(id);
    if (!record) {
      throw new NotFoundException(`Incident '${id}' not found`);
    }

    if (dto.status) record.status = dto.status;
    if (dto.severity) record.severity = dto.severity;
    if (dto.reason) record.reason = dto.reason;
    if (dto.resolutionNotes) record.resolutionNotes = dto.resolutionNotes;
    if (dto.metadata) record.metadata = { ...record.metadata, ...dto.metadata };
    record.updatedAt = new Date();

    if (record.status === IncidentStatus.RESOLVED && !record.resolvedAt) {
      record.resolvedAt = new Date();
    }

    await this.persistIncident(record, false);
    return record;
  }

  /**
   * Acknowledge an incident by an operator/admin.
   */
  public async acknowledgeIncident(id: string, actorId: string): Promise<ProviderIncidentRecord> {
    const record = this.memoryIncidents.get(id);
    if (!record) {
      throw new NotFoundException(`Incident '${id}' not found`);
    }

    record.status = IncidentStatus.INVESTIGATING;
    record.acknowledgedBy = actorId;
    record.acknowledgedAt = new Date();
    record.updatedAt = new Date();

    this.logger.log(`[INCIDENT_ACKNOWLEDGED] Incident [${id}] acknowledged by actor [${actorId}]`);
    await this.persistIncident(record, false);
    return record;
  }

  /**
   * Resolve an incident with resolution notes.
   */
  public async resolveIncident(
    id: string,
    actorId: string,
    notes: string,
  ): Promise<ProviderIncidentRecord> {
    const record = this.memoryIncidents.get(id);
    if (!record) {
      throw new NotFoundException(`Incident '${id}' not found`);
    }

    record.status = IncidentStatus.RESOLVED;
    record.resolvedAt = new Date();
    record.resolutionNotes = notes;
    record.updatedAt = new Date();
    record.metadata = {
      ...record.metadata,
      resolvedBy: actorId,
    };

    this.logger.log(`[INCIDENT_RESOLVED] Incident [${id}] resolved by actor [${actorId}]`);
    await this.persistIncident(record, false);
    return record;
  }

  /**
   * Get single incident by ID.
   */
  public getIncidentById(id: string): ProviderIncidentRecord {
    const record = this.memoryIncidents.get(id);
    if (!record) {
      throw new NotFoundException(`Incident '${id}' not found`);
    }
    return record;
  }

  /**
   * Get all active (unresolved) incidents.
   */
  public getActiveIncidents(): ProviderIncidentRecord[] {
    return Array.from(this.memoryIncidents.values()).filter(
      (inc) => inc.status !== IncidentStatus.RESOLVED,
    );
  }

  /**
   * Get all incidents for a specific provider.
   */
  public getIncidentsByProvider(providerId: string): ProviderIncidentRecord[] {
    const norm = providerId.toLowerCase();
    return Array.from(this.memoryIncidents.values()).filter(
      (inc) => inc.providerId.toLowerCase() === norm,
    );
  }

  /**
   * Filter and query incidents.
   */
  public queryIncidents(query?: IncidentFilterQuery): ProviderIncidentRecord[] {
    let list = Array.from(this.memoryIncidents.values());

    if (!query) return list.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    if (query.providerId) {
      const pid = query.providerId.toLowerCase();
      list = list.filter((i) => i.providerId.toLowerCase() === pid);
    }

    if (query.category) {
      list = list.filter((i) => i.category === query.category);
    }

    if (query.status) {
      list = list.filter((i) => i.status === query.status);
    }

    if (query.severity) {
      list = list.filter((i) => i.severity === query.severity);
    }

    if (query.from) {
      list = list.filter((i) => i.createdAt >= query.from!);
    }

    if (query.to) {
      list = list.filter((i) => i.createdAt <= query.to!);
    }

    list.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    if (query.limit && query.limit > 0) {
      list = list.slice(0, query.limit);
    }

    return list;
  }

  /**
   * Summarize incident statistics across the platform.
   */
  public getIncidentStats(): {
    totalIncidents: number;
    activeIncidents: number;
    resolvedIncidents: number;
    bySeverity: Record<IncidentSeverity, number>;
    byStatus: Record<IncidentStatus, number>;
  } {
    const all = Array.from(this.memoryIncidents.values());
    const bySeverity: Record<IncidentSeverity, number> = {
      [IncidentSeverity.CRITICAL]: 0,
      [IncidentSeverity.MAJOR]: 0,
      [IncidentSeverity.MEDIUM]: 0,
      [IncidentSeverity.LOW]: 0,
    };
    const byStatus: Record<IncidentStatus, number> = {
      [IncidentStatus.DETECTED]: 0,
      [IncidentStatus.INVESTIGATING]: 0,
      [IncidentStatus.IDENTIFIED]: 0,
      [IncidentStatus.MONITORING]: 0,
      [IncidentStatus.RESOLVED]: 0,
    };

    let activeCount = 0;
    let resolvedCount = 0;

    for (const inc of all) {
      if (bySeverity[inc.severity] !== undefined) bySeverity[inc.severity]++;
      if (byStatus[inc.status] !== undefined) byStatus[inc.status]++;

      if (inc.status === IncidentStatus.RESOLVED) {
        resolvedCount++;
      } else {
        activeCount++;
      }
    }

    return {
      totalIncidents: all.length,
      activeIncidents: activeCount,
      resolvedIncidents: resolvedCount,
      bySeverity,
      byStatus,
    };
  }

  private async persistIncident(record: ProviderIncidentRecord, isNew: boolean): Promise<void> {
    if (!this.prisma) return;
    try {
      if (isNew) {
        await (this.prisma as any).providerIncident.create({
          data: {
            id: record.id,
            providerId: record.providerId,
            category: record.category,
            title: record.title,
            status: record.status,
            severity: record.severity,
            circuitState: record.circuitState,
            startedAt: record.startedAt,
            resolvedAt: record.resolvedAt,
            reason: record.reason,
            metadata: {
              incidentType: record.incidentType,
              detectionSource: record.detectionSource,
              failureCount: record.failureCount,
              acknowledgedBy: record.acknowledgedBy,
              resolutionNotes: record.resolutionNotes,
              ...record.metadata,
            },
          },
        });
      } else {
        await (this.prisma as any).providerIncident.update({
          where: { id: record.id },
          data: {
            status: record.status,
            severity: record.severity,
            circuitState: record.circuitState,
            resolvedAt: record.resolvedAt,
            reason: record.reason,
            metadata: {
              incidentType: record.incidentType,
              detectionSource: record.detectionSource,
              failureCount: record.failureCount,
              acknowledgedBy: record.acknowledgedBy,
              resolutionNotes: record.resolutionNotes,
              ...record.metadata,
            },
          },
        });
      }
    } catch (err: any) {
      this.logger.debug(`Could not persist incident to DB (safely ignored): ${err.message}`);
    }
  }
}
