import { Injectable } from '@nestjs/common';
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
export class MockStorageAdapter implements StorageProvider {
  getProviderId(): string {
    return 'mock_storage';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.STORAGE;
  }

  getDisplayName(): string {
    return 'Mock Local Storage Provider';
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
    return 3000;
  }

  async getPresignedUploadUrl(req: PresignedUploadRequest): Promise<PresignedUploadResponse> {
    return {
      uploadUrl: `http://localhost:3000/uploads/mock-put/${req.key}`,
      key: req.key,
      publicUrl: req.isPublic ? `http://localhost:3000/uploads/mock-files/${req.key}` : null,
      expiresAt: new Date(Date.now() + 300000),
    };
  }

  async getPresignedDownloadUrl(req: PresignedDownloadRequest): Promise<PresignedDownloadResponse> {
    return {
      downloadUrl: `http://localhost:3000/uploads/mock-files/${req.key}`,
      expiresAt: new Date(Date.now() + 300000),
    };
  }

  async deleteObject(key: string): Promise<void> {}

  getPublicUrl(key: string): string | null {
    return `http://localhost:3000/uploads/mock-files/${key}`;
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Storage is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock storage test connection successful',
    };
  }
}
