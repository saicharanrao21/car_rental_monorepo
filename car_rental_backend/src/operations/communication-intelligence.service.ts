import { Injectable, Logger } from '@nestjs/common';
import { CustomerCommunicationProfile } from './operations-domain.types';

@Injectable()
export class CommunicationIntelligenceService {
  private readonly logger = new Logger(CommunicationIntelligenceService.name);

  // In-memory profile cache: userId -> CustomerCommunicationProfile
  private readonly profiles = new Map<string, CustomerCommunicationProfile>();

  // Default fallback channels in priority order
  private readonly DEFAULT_CHANNEL_HIERARCHY: Array<'WHATSAPP' | 'SMS' | 'PUSH' | 'EMAIL'> = [
    'WHATSAPP',
    'SMS',
    'PUSH',
    'EMAIL',
  ];

  /**
   * Get or create customer communication profile with default preferences.
   */
  public getOrCreateProfile(userId: string): CustomerCommunicationProfile {
    if (!this.profiles.has(userId)) {
      const defaultProfile: CustomerCommunicationProfile = {
        userId,
        preferredChannel: 'WHATSAPP',
        preferredLanguage: 'en',
        channelSuccessRates: {
          WHATSAPP: 0.95,
          SMS: 0.90,
          PUSH: 0.85,
          EMAIL: 0.80,
        },
        optedOutChannels: [],
        bestSendTimeWindow: {
          startHour: 9, // 9 AM
          endHour: 21,  // 9 PM
        },
        deliveryFailureCount: {
          WHATSAPP: 0,
          SMS: 0,
          PUSH: 0,
          EMAIL: 0,
        },
        lastUpdated: new Date().toISOString(),
      };
      this.profiles.set(userId, defaultProfile);
    }
    return this.profiles.get(userId)!;
  }

  /**
   * Update customer communication preferences.
   */
  public updatePreferences(
    userId: string,
    updates: Partial<CustomerCommunicationProfile>,
  ): CustomerCommunicationProfile {
    const profile = this.getOrCreateProfile(userId);
    if (updates.preferredChannel) profile.preferredChannel = updates.preferredChannel;
    if (updates.preferredLanguage) profile.preferredLanguage = updates.preferredLanguage;
    if (updates.optedOutChannels) profile.optedOutChannels = updates.optedOutChannels;
    if (updates.bestSendTimeWindow) profile.bestSendTimeWindow = updates.bestSendTimeWindow;
    profile.lastUpdated = new Date().toISOString();
    return profile;
  }

  /**
   * Resolve the optimal communication channel chain for a user,
   * accounting for preferences, opt-outs, and channel historical success rates.
   */
  public resolveChannelChain(
    userId: string,
    isTransactional = true,
  ): Array<'WHATSAPP' | 'SMS' | 'PUSH' | 'EMAIL'> {
    const profile = this.getOrCreateProfile(userId);

    // Build ordered list starting with user's preferred channel
    const candidateChannels = [...this.DEFAULT_CHANNEL_HIERARCHY];
    const preferred = profile.preferredChannel;

    // Put preferred at front if not already
    const filtered = candidateChannels.filter((c) => c !== preferred);
    const ordered = [preferred, ...filtered];

    // Filter out opted-out channels (unless critical transactional and only SMS is left)
    const available = ordered.filter((c) => !profile.optedOutChannels.includes(c));

    // Sort secondary fallback channels by historical success score
    if (available.length > 1) {
      const first = available[0];
      const rest = available.slice(1);
      rest.sort((a, b) => {
        const scoreA = profile.channelSuccessRates[a] ?? 0.5;
        const scoreB = profile.channelSuccessRates[b] ?? 0.5;
        return scoreB - scoreA;
      });
      return [first, ...rest];
    }

    return available.length > 0 ? available : ['SMS'];
  }

  /**
   * Feedback learning: records delivery success and adjusts channel score.
   */
  public recordDeliverySuccess(userId: string, channel: 'WHATSAPP' | 'SMS' | 'PUSH' | 'EMAIL'): void {
    const profile = this.getOrCreateProfile(userId);
    const currentScore = profile.channelSuccessRates[channel] ?? 0.8;
    // Exponential smoothing towards 1.0
    profile.channelSuccessRates[channel] = Math.min(1.0, currentScore * 0.9 + 0.1);
    profile.lastUpdated = new Date().toISOString();
    this.logger.debug(`[COMM_LEARN] User ${userId} ${channel} score improved to ${profile.channelSuccessRates[channel].toFixed(3)}`);
  }

  /**
   * Feedback learning: records delivery failure, increments failure count, penalizes channel score.
   */
  public recordDeliveryFailure(userId: string, channel: 'WHATSAPP' | 'SMS' | 'PUSH' | 'EMAIL'): void {
    const profile = this.getOrCreateProfile(userId);
    profile.deliveryFailureCount[channel] = (profile.deliveryFailureCount[channel] || 0) + 1;
    const currentScore = profile.channelSuccessRates[channel] ?? 0.8;
    // Exponential decay towards 0.0
    profile.channelSuccessRates[channel] = Math.max(0.1, currentScore * 0.8);
    profile.lastUpdated = new Date().toISOString();
    this.logger.warn(`[COMM_LEARN] User ${userId} ${channel} score decayed to ${profile.channelSuccessRates[channel].toFixed(3)} (failures: ${profile.deliveryFailureCount[channel]})`);
  }

  /**
   * Check if current time is within user's quiet hours.
   */
  public isQuietHours(userId: string, userTimezone = 'Asia/Kolkata'): boolean {
    const profile = this.getOrCreateProfile(userId);
    const window = profile.bestSendTimeWindow;
    if (!window) return false;

    // Approximate hour in target timezone
    try {
      const localDate = new Date(new Date().toLocaleString('en-US', { timeZone: userTimezone }));
      const currentHour = localDate.getHours();
      return currentHour < window.startHour || currentHour >= window.endHour;
    } catch {
      const currentHour = new Date().getHours();
      return currentHour < window.startHour || currentHour >= window.endHour;
    }
  }

  /**
   * Extension point for future AI/ML optimal send time predictor.
   */
  public predictOptimalSendTime(userId: string): { recommendedDelayMinutes: number; confidenceScore: number } {
    const profile = this.getOrCreateProfile(userId);
    const isQuiet = this.isQuietHours(userId);
    if (isQuiet) {
      return { recommendedDelayMinutes: 120, confidenceScore: 0.85 };
    }
    return { recommendedDelayMinutes: 0, confidenceScore: 0.92 };
  }
}
