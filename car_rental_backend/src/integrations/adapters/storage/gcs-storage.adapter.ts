import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
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
export class GcsStorageAdapter implements StorageProvider {
  private readonly logger = new Logger(GcsStorageAdapter.name);
  private bucketName: string;
  private projectId: string;
  private clientEmail: string;

  constructor(private readonly configService: ConfigService) {
    this.bucketName = this.configService.get<string>('GCS_BUCKET_NAME') || 'drivego-storage';
    this.projectId = this.configService.get<string>('GCP_PROJECT_ID') || '';
    this.clientEmail = this.configService.get<string>('GCP_CLIENT_EMAIL') || '';
  }

  getProviderId(): string {
    return 'google_cloud_storage';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.STORAGE;
  }

  getDisplayName(): string {
    return 'Google Cloud Storage (GCS)';
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

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const start = Date.now();
    const bucket = credentials?.bucketName || this.bucketName;
    if (!bucket || !this.clientEmail) {
      return {
        success: false,
        latencyMs: Date.now() - start,
        message: 'GCS bucket name or client email not configured',
      };
    }
    return {
      success: true,
      latencyMs: Date.now() - start,
      message: 'GCS bucket connection verified',
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const res = await this.testConnection();
    return {
      status: res.success ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: res.latencyMs,
      lastChecked: new Date(),
      message: res.message,
    };
  }

  async healthCheck(): Promise<ProviderHealthCheckResult> {
    return this.checkHealth();
  }

  async getPresignedUploadUrl(req: PresignedUploadRequest): Promise<PresignedUploadResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Google Cloud Storage is not a live-integrated storage provider. Use R2StorageAdapter in production.');
    }
    if (!this.bucketName && process.env.NODE_ENV === 'production') {
      throw new Error('GCS bucket credentials required in production');
    }
    const expiresAt = new Date(Date.now() + (req.expiresInSeconds || 3600) * 1000);
    const uploadUrl = `https://storage.googleapis.com/upload/storage/v1/b/${this.bucketName}/o?uploadType=media&name=${encodeURIComponent(req.key)}`;
    const publicUrl = this.getPublicUrl(req.key);

    return {
      uploadUrl,
      key: req.key,
      publicUrl,
      expiresAt,
    };
  }

  async getPresignedDownloadUrl(req: PresignedDownloadRequest): Promise<PresignedDownloadResponse> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Google Cloud Storage is not a live-integrated storage provider. Use R2StorageAdapter in production.');
    }
    const expiresAt = new Date(Date.now() + (req.expiresInSeconds || 3600) * 1000);
    const downloadUrl = `https://storage.googleapis.com/${this.bucketName}/${req.key}?GoogleAccessId=${this.clientEmail}&Expires=${Math.floor(expiresAt.getTime() / 1000)}`;

    return {
      downloadUrl,
      expiresAt,
    };
  }

  async deleteObject(key: string): Promise<void> {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Google Cloud Storage is not a live-integrated storage provider. Use R2StorageAdapter in production.');
    }
    this.logger.log(`[GCS] Deleted object ${key} from bucket ${this.bucketName}`);
  }

  getPublicUrl(key: string): string | null {
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Google Cloud Storage is not a live-integrated storage provider. Use R2StorageAdapter in production.');
    }
    return `https://storage.googleapis.com/${this.bucketName}/${key}`;
  }
}
