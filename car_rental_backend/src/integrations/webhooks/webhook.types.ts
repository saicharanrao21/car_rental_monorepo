export interface WebhookIngestParams {
  gateway: string;
  rawBody: string;
  signature: string;
  headers?: Record<string, any>;
  secret?: string;
  timestamp?: number;
}

export interface WebhookProcessResult {
  received: boolean;
  duplicate?: boolean;
  alreadyProcessed?: boolean;
  eventId: string;
  eventType?: string;
  status: 'PROCESSED' | 'FAILED' | 'DUPLICATE' | 'RECEIVED';
  error?: string;
  data?: any;
}

export interface NormalizedGenericWebhookEvent {
  eventId: string;
  gateway: string;
  eventType: string;
  aggregateId?: string;
  timestamp: Date;
  payload: any;
}

export interface WebhookVerifier {
  verifySignature(rawBody: string, signature: string, secret: string, headers?: any): boolean;
}
