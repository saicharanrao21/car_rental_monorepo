import { Injectable, Logger } from '@nestjs/common';
import {
  CommunicationChannel,
  CommunicationMessageType,
  CommunicationRecipient,
  CommunicationPriority,
} from './communication.types';

export interface ComplianceEvaluation {
  allowed: boolean;
  reason?: string;
  isQuietHours: boolean;
  dndBlocked: boolean;
  consentMissing: boolean;
}

@Injectable()
export class CommunicationComplianceService {
  private readonly logger = new Logger(CommunicationComplianceService.name);

  // In-memory blocked numbers/emails for security / customer opt-out
  private readonly globalBlocklist = new Set<string>(['+919876500000', 'spam_user@badmail.com']);

  addToBlocklist(identifier: string): void {
    this.globalBlocklist.add(identifier.trim().toLowerCase());
  }

  removeFromBlocklist(identifier: string): void {
    this.globalBlocklist.delete(identifier.trim().toLowerCase());
  }

  isBlocklisted(identifier: string): boolean {
    return this.globalBlocklist.has(identifier.trim().toLowerCase());
  }

  /**
   * Evaluates whether a communication is legally and policy-wise permitted.
   */
  evaluateCompliance(params: {
    channel: CommunicationChannel;
    messageType: CommunicationMessageType;
    priority?: CommunicationPriority;
    recipient: CommunicationRecipient;
    referenceDate?: Date;
    quietHoursConfig?: {
      enabled: boolean;
      startHour: number; // e.g. 21 (9 PM)
      endHour: number;   // e.g. 8 (8 AM)
      timeZone?: string;
    };
  }): ComplianceEvaluation {
    const {
      channel,
      messageType,
      priority = CommunicationPriority.NORMAL,
      recipient,
      referenceDate = new Date(),
      quietHoursConfig = { enabled: true, startHour: 21, endHour: 8, timeZone: 'Asia/Kolkata' },
    } = params;

    const contactId = recipient.phone || recipient.email || recipient.userId || '';

    // 1. Blocklist check
    if (contactId && this.isBlocklisted(contactId)) {
      return {
        allowed: false,
        reason: `Recipient [${contactId}] is in the communication opt-out blocklist.`,
        isQuietHours: false,
        dndBlocked: true,
        consentMissing: false,
      };
    }

    const isCritical =
      priority === CommunicationPriority.CRITICAL ||
      messageType === CommunicationMessageType.OTP ||
      messageType === CommunicationMessageType.CRITICAL_ALERT;

    // 2. Consent check
    if (!isCritical) {
      if (messageType === CommunicationMessageType.MARKETING) {
        if (recipient.marketingOptIn === false) {
          return {
            allowed: false,
            reason: `Recipient has opted out of marketing communications.`,
            isQuietHours: false,
            dndBlocked: false,
            consentMissing: true,
          };
        }
      }

      // Channel-specific explicit consent checks
      if (channel === CommunicationChannel.WHATSAPP && recipient.whatsappConsent === false) {
        return {
          allowed: false,
          reason: `Recipient has revoked WhatsApp communication consent.`,
          isQuietHours: false,
          dndBlocked: false,
          consentMissing: true,
        };
      }

      if (channel === CommunicationChannel.SMS && recipient.smsConsent === false) {
        return {
          allowed: false,
          reason: `Recipient has revoked SMS communication consent.`,
          isQuietHours: false,
          dndBlocked: false,
          consentMissing: true,
        };
      }
    }

    // 3. National DND / NCPR Registry check
    if (recipient.dndRegistered && messageType === CommunicationMessageType.MARKETING) {
      return {
        allowed: false,
        reason: `Recipient phone is registered on the National DND / NCPR registry. Marketing prohibited.`,
        isQuietHours: false,
        dndBlocked: true,
        consentMissing: false,
      };
    }

    // 4. Quiet Hours Check (TRAI / FCC regulations: No promotional calls/SMS between 21:00 and 08:00)
    const isQuiet = this.isInQuietHours(referenceDate, quietHoursConfig);
    if (isQuiet && messageType === CommunicationMessageType.MARKETING && !isCritical) {
      return {
        allowed: false,
        reason: `Promotional messaging blocked during quiet hours (${quietHoursConfig.startHour}:00 - ${quietHoursConfig.endHour}:00).`,
        isQuietHours: true,
        dndBlocked: false,
        consentMissing: false,
      };
    }

    return {
      allowed: true,
      isQuietHours: isQuiet,
      dndBlocked: false,
      consentMissing: false,
    };
  }

  /**
   * Helper to determine if current time is within quiet hours.
   */
  private isInQuietHours(
    date: Date,
    config: { enabled: boolean; startHour: number; endHour: number; timeZone?: string },
  ): boolean {
    if (!config.enabled) return false;

    let hours: number;
    if (config.timeZone) {
      try {
        const formatter = new Intl.DateTimeFormat('en-US', {
          timeZone: config.timeZone,
          hour: 'numeric',
          hour12: false,
        });
        hours = parseInt(formatter.format(date), 10);
        if (hours === 24) hours = 0;
      } catch {
        hours = date.getHours();
      }
    } else {
      hours = date.getHours();
    }

    const { startHour, endHour } = config;

    if (startHour > endHour) {
      // Over midnight: e.g. 21 (9 PM) to 8 (8 AM)
      return hours >= startHour || hours < endHour;
    } else {
      return hours >= startHour && hours < endHour;
    }
  }
}
