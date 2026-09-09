export enum AiCapability {
  CHAT = 'CHAT',
  TEXT_GENERATION = 'TEXT_GENERATION',
  SUMMARIZATION = 'SUMMARIZATION',
  CLASSIFICATION = 'CLASSIFICATION',
  EXTRACTION = 'EXTRACTION',
  EMBEDDINGS = 'EMBEDDINGS',
  VISION = 'VISION',
  TOOL_CALLING = 'TOOL_CALLING',
}

export interface AiChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

export interface AiChatPayload {
  messages: AiChatMessage[];
  temperature?: number;
  maxTokens?: number;
  model?: string;
}

export interface AiTextGenPayload {
  prompt: string;
  systemInstruction?: string;
  temperature?: number;
  maxTokens?: number;
}

export interface AiSummarizePayload {
  text: string;
  targetLength?: 'short' | 'medium' | 'detailed';
  format?: 'bullet_points' | 'paragraph';
}

export interface AiClassificationPayload {
  text: string;
  candidateLabels: string[];
}

export interface AiExtractionPayload {
  text: string;
  schema: Record<string, string>; // e.g. { customerName: 'string', pickupDate: 'date', vehicleCategory: 'string' }
}

export interface AiEmbeddingPayload {
  texts: string[];
}

export interface AiResult {
  text?: string;
  summary?: string;
  classification?: {
    label: string;
    confidence: number;
    allScores: Record<string, number>;
  };
  extractedData?: Record<string, any>;
  embeddings?: number[][];
  modelUsed: string;
  tokensUsed?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
  provider: string;
}
