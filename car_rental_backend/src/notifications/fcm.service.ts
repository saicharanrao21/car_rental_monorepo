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

    if (
      !projectId ||
      !clientEmail ||
      !privateKey ||
      privateKey.startsWith('YOUR_') ||
      privateKey.startsWith('placeholder')
    ) {
      this.logger.warn('Firebase credentials not fully configured. Running FCM in Mock mode.');
      this.isMock = true;
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
        this.logger.error('Failed to initialize Firebase Admin, falling back to Mock mode:', error);
        this.isMock = true;
      }
    }
  }

  async sendToUser(userId: string, title: string, body: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true },
    });

    if (!user || !user.fcmToken) {
      this.logger.log(`[FCM] Skip push for user ${userId} - no token registered.`);
      return;
    }

    if (this.isMock) {
      this.logger.log(`[FCM-MOCK] Push to ${userId} (Token: ${user.fcmToken}): "${title}" - "${body}"`);
      return;
    }

    try {
      await getMessaging().send({
        token: user.fcmToken,
        notification: {
          title,
          body,
        },
      });
      this.logger.log(`[FCM] Push sent to user ${userId}`);
    } catch (error) {
      this.logger.error(`[FCM] Failed to send push to user ${userId} (Token: ${user.fcmToken}):`, error);
    }
  }

  async sendMulticast(tokens: string[], title: string, body: string) {
    if (tokens.length === 0) return;

    if (this.isMock) {
      this.logger.log(`[FCM-MOCK] Multicast to ${tokens.length} tokens: "${title}" - "${body}"`);
      return;
    }

    // Send in chunks of 500 (FCM limit)
    const chunkSize = 500;
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      try {
        await getMessaging().sendEachForMulticast({
          tokens: chunk,
          notification: {
            title,
            body,
          },
        });
        this.logger.log(`[FCM] Multicast chunk of ${chunk.length} tokens sent successfully.`);
      } catch (error) {
        this.logger.error('[FCM] Multicast chunk failed to send:', error);
      }
    }
  }
}
