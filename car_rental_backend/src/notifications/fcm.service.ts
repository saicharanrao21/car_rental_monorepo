import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private isMock = true;

  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.configService.get<string>('FIREBASE_PRIVATE_KEY');

    const isProduction =
      this.configService.get<string>('NODE_ENV') === 'production';

    if (
      !projectId ||
      !clientEmail ||
      !privateKey ||
      privateKey.startsWith('YOUR_') ||
      privateKey.startsWith('placeholder')
    ) {
      if (isProduction) {
        this.logger.warn(
          'Firebase credentials not configured in production. Push notifications are disabled.',
        );
        this.isMock = false;
      } else {
        this.logger.warn(
          'Firebase credentials not fully configured. Running FCM in Mock mode.',
        );
        this.isMock = true;
      }
    } else {
      try {
        if (getApps().length === 0) {
          const formattedPrivateKey = privateKey.replace(/\\n/g, '\n');
          initializeApp({
            credential: cert({
              projectId,
              clientEmail,
              privateKey: formattedPrivateKey,
            }),
          });
        }
        this.isMock = false;
        this.logger.log('Firebase Admin initialized successfully.');
      } catch (error) {
        if (isProduction) {
          this.logger.error(
            'Failed to initialize Firebase Admin in production. Push notifications are disabled.',
            error,
          );
          this.isMock = false;
        } else {
          this.logger.error(
            'Failed to initialize Firebase Admin, falling back to Mock mode in development:',
            error,
          );
          this.isMock = true;
        }
      }
    }
  }

  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true },
    });

    if (!user || !user.fcmToken) {
      this.logger.log(
        `[FCM] Skip push for user ${userId} - no token registered.`,
      );
      return;
    }

    return this.sendToToken(user.fcmToken, title, body, data);
  }

  async sendToToken(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<{ success: boolean; messageId?: string; error?: string }> {
    if (this.isMock) {
      const mockMessageId = `projects/drivego/messages/mock_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      this.logger.log(
        `[FCM-MOCK] Push to Token: ${token} | "${title}" - "${body}" | ID: ${mockMessageId}`,
      );
      return { success: true, messageId: mockMessageId };
    }

    try {
      const response = await getMessaging().send({
        token,
        notification: {
          title,
          body,
        },
        data: data || {},
      });
      this.logger.log(`[FCM] Push sent successfully: ${response}`);
      return { success: true, messageId: response };
    } catch (error: any) {
      const errorMsg = error?.message || String(error);
      this.logger.error(`[FCM] Push failed for token ${token}:`, error);

      // Auto-invalidate dead tokens
      if (
        errorMsg.includes('registration-token-not-registered') ||
        errorMsg.includes('invalid-registration-token') ||
        error?.code === 'messaging/registration-token-not-registered' ||
        error?.code === 'messaging/invalid-registration-token'
      ) {
        await this.prisma.userDevice.updateMany({
          where: { token },
          data: { isActive: false },
        });
        this.logger.warn(`[FCM] Auto-deactivated invalid device token: ${token}`);
      }

      return { success: false, error: errorMsg };
    }
  }

  async sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ) {
    if (tokens.length === 0) return;

    if (this.isMock) {
      this.logger.log(
        `[FCM-MOCK] Multicast to ${tokens.length} tokens: "${title}" - "${body}"`,
      );
      return;
    }

    // Send in chunks of 500 (FCM limit)
    const chunkSize = 500;
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      try {
        const response = await getMessaging().sendEachForMulticast({
          tokens: chunk,
          notification: {
            title,
            body,
          },
          data: data || {},
        });
        this.logger.log(
          `[FCM] Multicast chunk of ${chunk.length} tokens: success=${response.successCount}, failure=${response.failureCount}`,
        );

        // Deactivate invalid tokens from response
        if (response.failureCount > 0) {
          const invalidTokens: string[] = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success && resp.error) {
              const code = resp.error.code;
              if (
                code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token'
              ) {
                invalidTokens.push(chunk[idx]);
              }
            }
          });

          if (invalidTokens.length > 0) {
            await this.prisma.userDevice.updateMany({
              where: { token: { in: invalidTokens } },
              data: { isActive: false },
            });
            this.logger.warn(
              `[FCM] Deactivated ${invalidTokens.length} stale multicast tokens.`,
            );
          }
        }
      } catch (error) {
        this.logger.error('[FCM] Multicast chunk failed to send:', error);
      }
    }
  }
}
