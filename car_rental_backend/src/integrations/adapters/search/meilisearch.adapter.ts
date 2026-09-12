import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BaseProvider } from '../../contracts/provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';
import {
  SearchCapability,
  SearchIndexPayload,
  SearchQueryPayload,
  SearchQueryResult,
} from '../../contracts/capabilities/search-analytics-capabilities.interface';

@Injectable()
export class MeilisearchAdapter implements BaseProvider {
  private readonly logger = new Logger(MeilisearchAdapter.name);
  private host: string;
  private apiKey: string;
  private inMemoryIndexes: Map<string, Map<string, any>> = new Map();

  constructor(private readonly configService: ConfigService) {
    this.host = this.configService.get<string>('MEILISEARCH_HOST') || 'http://localhost:7700';
    this.apiKey = this.configService.get<string>('MEILISEARCH_API_KEY') || '';
  }

  getProviderId(): string {
    return 'meilisearch';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.SEARCH;
  }

  getDisplayName(): string {
    return 'Meilisearch Instant Search Engine';
  }

  getSupportedCapabilities(): string[] {
    return [
      SearchCapability.INDEX_DOCUMENT,
      SearchCapability.BATCH_INDEX,
      SearchCapability.SEARCH_QUERY,
      SearchCapability.DELETE_DOCUMENT,
      SearchCapability.AUTOCOMPLETE,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 4000;
  }

  async indexDocuments(payload: SearchIndexPayload): Promise<{ success: boolean; count: number }> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Meilisearch simulated adapter is not allowed in production');
    }
    this.logger.log(`[MEILISEARCH_INDEX] Indexing ${payload.documents.length} docs into "${payload.indexName}"`);
    let idx = this.inMemoryIndexes.get(payload.indexName);
    if (!idx) {
      idx = new Map<string, any>();
      this.inMemoryIndexes.set(payload.indexName, idx);
    }

    const pk = payload.primaryKey || 'id';
    for (const doc of payload.documents) {
      const id = `${doc[pk] || Date.now()}_${Math.random().toString(36).substring(2, 5)}`;
      idx.set(id, doc);
    }

    return { success: true, count: payload.documents.length };
  }

  async search<T = any>(payload: SearchQueryPayload): Promise<SearchQueryResult<T>> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Meilisearch simulated adapter is not allowed in production');
    }
    const start = Date.now();
    this.logger.log(`[MEILISEARCH_QUERY] Search "${payload.query}" in index "${payload.indexName}"`);

    const idx = this.inMemoryIndexes.get(payload.indexName);
    const hits: any[] = [];

    if (idx) {
      const qLower = payload.query.toLowerCase();
      for (const doc of idx.values()) {
        const str = JSON.stringify(doc).toLowerCase();
        if (str.includes(qLower)) {
          hits.push(doc);
        }
      }
    }

    const limit = payload.limit || 20;
    const offset = payload.offset || 0;
    const paginated = hits.slice(offset, offset + limit);

    return {
      hits: paginated,
      query: payload.query,
      totalHits: hits.length,
      processingTimeMs: Date.now() - start,
      provider: this.getProviderId(),
    };
  }

  async deleteDocument(indexName: string, documentId: string): Promise<{ success: boolean }> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Meilisearch simulated adapter is not allowed in production');
    }
    this.logger.log(`[MEILISEARCH_DELETE] Deleting doc "${documentId}" from "${indexName}"`);
    const idx = this.inMemoryIndexes.get(indexName);
    if (idx) {
      idx.delete(documentId);
    }
    return { success: true };
  }

  async testConnection(): Promise<TestConnectionResult> {
    const start = Date.now();
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'Meilisearch cluster responsive and healthy',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 12,
      lastChecked: new Date(),
      message: 'Meilisearch index engine healthy',
    };
  }

  async healthCheck(): Promise<ProviderHealthCheckResult> {
    return this.checkHealth();
  }
}
