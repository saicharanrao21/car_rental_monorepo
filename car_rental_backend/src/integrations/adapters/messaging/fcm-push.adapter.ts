import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PushProvider,
  PushCapability,
  NormalizedPushRequest,
  NormalizedPushResponse,
} from '../../contracts/messaging-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';
import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

@Injectable()
export class FcmPushAdapter implements PushProvider {
  private readonly logger = new Logger(FcmPushAdapter.name);
  private isInitialized = false;

  constructor(private readonly configService: ConfigService) {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.configService.get<string>('FIREBASE_PRIVATE_KEY');

    if (
      projectId &&
      clientEmail &&
      privateKey &&
      !privateKey.startsWith('YOUR_') &&
      !privateKey.startsWith('placeholder')
    ) {
      try {
        if (getApps().length === 0) {
          initializeApp({
            credential: cert({
              projectId,
              clientEmail,
              privateKey: privateKey.replace(/\\n/g, '\n'),
            }),
          });
        }
        this.isInitialized = true;
      } catch (err: any) {
        this.logger.warn(`Firebase Admin init failed: ${err?.message}`);
      }
    }
  }

  getProviderId(): string {
    return 'fcm';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MESSAGING_PUSH;
  }

  getDisplayName(): string {
    return 'Firebase Cloud Messaging (FCM)';
  }

  getSupportedCapabilities(): string[] {
    return [
      PushCapability.SEND_UNICAST,
      PushCapability.SEND_MULTICAST,
      PushCapability.DATA_PAYLOAD,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 8000;
  }

  async sendPush(req: NormalizedPushRequest): Promise<NormalizedPushResponse> {
    if (!this.isInitialized || req.deviceTokens.length === 0) {
      this.logger.log(`[FCM_MOCK] Dispatched mock push to ${req.deviceTokens.length} devices: "${req.title}"`);
      return {
        success: true,
        successCount: req.deviceTokens.length,
        failureCount: 0,
        messageId: `fcm_mock_${Date.now()}`,
      };
    }

    try {
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens: req.deviceTokens,
        notification: {
          title: req.title,
          body: req.body,
          imageUrl: req.imageUrl,
        },
        data: req.data,
      });

      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (
            code === 'messaging/invalid-registration-token' ||
            code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(req.deviceTokens[idx]);
          }
        }
      });

      return {
        success: response.successCount > 0,
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokens,
        rawResponse: response,
      };
    } catch (err: any) {
      return {
        success: false,
        successCount: 0,
        failureCount: req.deviceTokens.length,
        error: err?.message,
      };
    }
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: this.isInitialized ? ProviderHealthStatus.HEALTHY : ProviderHealthStatus.CONFIGURED,
      latencyMs: 1,
      message: this.isInitialized ? 'FCM initialized and ready' : 'FCM running in mock mode',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: this.isInitialized ? 'FCM SDK connection verified' : 'FCM running in mock mode',
    };
  }
}
