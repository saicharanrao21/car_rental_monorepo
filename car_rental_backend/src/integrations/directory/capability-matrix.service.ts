import { Injectable, Logger } from '@nestjs/common';
import {
  CapabilityMatchRequest,
  CapabilityMatchResult,
  NormalizedCapability,
} from './capability-matrix.types';
import { ProviderDirectoryMetadata } from './provider-directory.types';

@Injectable()
export class CapabilityMatrixService {
  private readonly logger = new Logger(CapabilityMatrixService.name);

  /**
   * Normalizes an incoming capability string to canonical format.
   */
  public normalize(capability: string): string {
    if (!capability) return '';
    const clean = capability.trim().toUpperCase().replace(/[\s-]+/g, '_');
    return clean;
  }

  /**
   * Evaluates how well a provider satisfies requested capabilities.
   */
  public evaluateProviderMatch(
    provider: ProviderDirectoryMetadata,
    request: CapabilityMatchRequest,
  ): CapabilityMatchResult {
    const providerCaps = new Set(provider.supportedCapabilities.map((c) => this.normalize(c)));

    const matchedRequired: string[] = [];
    const missingRequired: string[] = [];

    for (const reqCap of request.requiredCapabilities) {
      const normalizedReq = this.normalize(reqCap);
      if (providerCaps.has(normalizedReq) || this.isFuzzyMatch(normalizedReq, providerCaps)) {
        matchedRequired.push(reqCap);
      } else {
        missingRequired.push(reqCap);
      }
    }

    const matchedPreferred: string[] = [];
    if (request.preferredCapabilities) {
      for (const prefCap of request.preferredCapabilities) {
        const normalizedPref = this.normalize(prefCap);
        if (providerCaps.has(normalizedPref) || this.isFuzzyMatch(normalizedPref, providerCaps)) {
          matchedPreferred.push(prefCap);
        }
      }
    }

    const totalRequired = request.requiredCapabilities.length;
    const coveragePercent =
      totalRequired === 0
        ? 100
        : Math.round((matchedRequired.length / totalRequired) * 100);

    const isFullyCapable = missingRequired.length === 0;

    return {
      providerId: provider.providerId,
      matchedRequired,
      matchedPreferred,
      missingRequired,
      coveragePercent,
      isFullyCapable,
    };
  }

  /**
   * Filters and ranks an array of providers based on capability coverage.
   */
  public rankProvidersByCapability(
    providers: ProviderDirectoryMetadata[],
    request: CapabilityMatchRequest,
  ): Array<{ provider: ProviderDirectoryMetadata; match: CapabilityMatchResult }> {
    return providers
      .map((p) => ({
        provider: p,
        match: this.evaluateProviderMatch(p, request),
      }))
      .filter((item) => item.match.isFullyCapable)
      .sort((a, b) => b.match.matchedPreferred.length - a.match.matchedPreferred.length);
  }

  public getAllNormalizedCapabilities(): string[] {
    return Object.values(NormalizedCapability);
  }

  public getCapabilitiesForCategory(category: any): string[] {
    const all = Object.values(NormalizedCapability);
    const catStr = String(category).toUpperCase();
    const prefix = catStr.split('_')[0];
    const filtered = all.filter((c) => c.startsWith(prefix) || c.includes(prefix));
    return filtered.length > 0 ? filtered : all;
  }

  private isFuzzyMatch(requested: string, providerCaps: Set<string>): boolean {
    for (const cap of providerCaps) {
      if (cap.includes(requested) || requested.includes(cap)) {
        return true;
      }
      // Aliases
      if (
        (requested === 'CREATE_PAYMENT' && cap.includes('PAYMENT')) ||
        (requested === 'CAPTURE' && cap.includes('CAPTURE')) ||
        (requested === 'REFUND' && cap.includes('REFUND')) ||
        (requested === 'SEND_TEMPLATE' && cap.includes('TEMPLATE')) ||
        (requested === 'SEND_TEXT' && cap.includes('TEXT'))
      ) {
        return true;
      }
    }
    return false;
  }
}
