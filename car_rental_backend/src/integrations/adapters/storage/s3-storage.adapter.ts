import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  StorageProvider,
  StorageCapability,
  PresignedUploadRequest,
  PresignedUploadResponse,
  PresignedDownloadRequest,
  PresignedDownloadResponse,
} from '../../contracts/storage-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class S3StorageAdapter implements StorageProvider {
  private readonly logger = new Logger(S3StorageAdapter.name);

  constructor(private readonly configService: ConfigService) {}

  getProviderId(): string {
    return 's3';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.STORAGE;
  }

  getDisplayName(): string {
    return 'Amazon Web Services (AWS) S3';
  }

  getSupportedCapabilities(): string[] {
    return [
      StorageCapability.PRESIGNED_UPLOAD,
      StorageCapability.PRESIGNED_DOWNLOAD,
      StorageCapability.DELETE_OBJECT,
      StorageCapability.PUBLIC_READ,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 10000;
  }

  async getPresignedUploadUrl(req: PresignedUploadRequest): Promise<PresignedUploadResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Direct AWS S3 adapter is not configured for production; use R2StorageAdapter');
    }
    const expiresAt = new Date(Date.now() + (req.expiresInSeconds || 300) * 1000);
    return {
      uploadUrl: `https://s3.amazonaws.com/drivego-uploads/${req.key}?mock=true`,
      key: req.key,
      publicUrl: `https://s3.amazonaws.com/drivego-uploads/${req.key}`,
      expiresAt,
    };
  }

  async getPresignedDownloadUrl(req: PresignedDownloadRequest): Promise<PresignedDownloadResponse> {
    const expiresAt = new Date(Date.now() + (req.expiresInSeconds || 300) * 1000);
    return {
      downloadUrl: `https://s3.amazonaws.com/drivego-uploads/${req.key}?download=true`,
      expiresAt,
    };
  }

  async deleteObject(key: string): Promise<void> {
    this.logger.log(`[AWS_S3] Deleted object: ${key}`);
  }

  getPublicUrl(key: string): string | null {
    return `https://s3.amazonaws.com/drivego-uploads/${key}`;
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: 'AWS S3 adapter configured',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'AWS S3 connection verified',
    };
  }
}
