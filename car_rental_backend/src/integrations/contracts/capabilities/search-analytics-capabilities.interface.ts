export enum SearchCapability {
  INDEX_DOCUMENT = 'INDEX_DOCUMENT',
  BATCH_INDEX = 'BATCH_INDEX',
  SEARCH_QUERY = 'SEARCH_QUERY',
  DELETE_DOCUMENT = 'DELETE_DOCUMENT',
  AUTOCOMPLETE = 'AUTOCOMPLETE',
}

export enum AnalyticsCapability {
  TRACK_EVENT = 'TRACK_EVENT',
  IDENTIFY_USER = 'IDENTIFY_USER',
  BATCH_EVENTS = 'BATCH_EVENTS',
}

export interface SearchIndexPayload {
  indexName: string;
  documents: Array<Record<string, any>>;
  primaryKey?: string;
}

export interface SearchQueryPayload {
  indexName: string;
  query: string;
  filter?: string | Record<string, any>;
  limit?: number;
  offset?: number;
  facets?: string[];
  sort?: string[];
}

export interface SearchQueryResult<T = any> {
  hits: T[];
  query: string;
  totalHits: number;
  processingTimeMs: number;
  facetDistribution?: Record<string, Record<string, number>>;
  provider: string;
}

export interface AnalyticsEventPayload {
  distinctId: string;
  event: string;
  properties?: Record<string, any>;
  timestamp?: Date;
}

export interface AnalyticsIdentifyPayload {
  distinctId: string;
  properties: Record<string, any>;
}

export interface AnalyticsResult {
  success: boolean;
  eventsAccepted: number;
  provider: string;
}
