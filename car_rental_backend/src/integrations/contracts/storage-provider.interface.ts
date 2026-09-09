import { BaseProvider } from './provider.interface';

export enum StorageCapability {
  PRESIGNED_UPLOAD = 'PRESIGNED_UPLOAD',
  PRESIGNED_DOWNLOAD = 'PRESIGNED_DOWNLOAD',
  DIRECT_UPLOAD = 'DIRECT_UPLOAD',
  DELETE_OBJECT = 'DELETE_OBJECT',
  PUBLIC_READ = 'PUBLIC_READ',
}

export interface PresignedUploadRequest {
  key: string;
  contentType: string;
  expiresInSeconds?: number;
  metadata?: Record<string, string>;
  isPublic?: boolean;
}

export interface PresignedUploadResponse {
  uploadUrl: string;
  key: string;
  publicUrl?: string | null;
  expiresAt: Date;
  headers?: Record<string, string>;
}

export interface PresignedDownloadRequest {
  key: string;
  expiresInSeconds?: number;
}

export interface PresignedDownloadResponse {
  downloadUrl: string;
  expiresAt: Date;
}

export interface StorageProvider extends BaseProvider {
  getPresignedUploadUrl(req: PresignedUploadRequest): Promise<PresignedUploadResponse>;
  getPresignedDownloadUrl(req: PresignedDownloadRequest): Promise<PresignedDownloadResponse>;
  deleteObject(key: string): Promise<void>;
  getPublicUrl(key: string): string | null;
}
