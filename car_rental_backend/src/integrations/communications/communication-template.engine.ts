import { Injectable, Logger } from '@nestjs/common';
import { CommunicationChannel } from './communication.types';

export interface RenderedCommunication {
  channel: CommunicationChannel;
  language: string;
  templateName: string;
  subject?: string;
  body: string;
  html?: string;
  title?: string;
  speechScript?: string;
  dltTemplateId?: string;
  dltEntityId?: string;
  metaTemplateId?: string;
  buttons?: Array<{ type: 'URL' | 'QUICK_REPLY'; text: string; payload?: string }>;
  variablesUsed: Record<string, string | number>;
}

@Injectable()
export class CommunicationTemplateEngine {
  private readonly logger = new Logger(CommunicationTemplateEngine.name);

  // Multi-lingual catalog of canonical templates
  private readonly templateRepository: Record<
    string,
    Record<
      string,
      {
        subject?: string;
        body: string;
        html?: string;
        title?: string;
        speechScript?: string;
        dltTemplateId?: string;
        buttons?: any[];
      }
    >
  > = {
    BOOKING_CONFIRMATION: {
      en: {
        title: 'Booking Confirmed! 🚗',
        subject: 'Your DriveGo Booking #{{bookingId}} is Confirmed',
        body: 'Hello {{customerName}}, your booking for {{vehicleName}} (#{{bookingId}}) is confirmed for pickup on {{pickupTime}} at {{pickupLocation}}. Drive safe!',
        html: '<div style="font-family:sans-serif;"><h2>Booking Confirmed!</h2><p>Hello <b>{{customerName}}</b>,</p><p>Your booking for <b>{{vehicleName}}</b> (ID: <code>{{bookingId}}</code>) is confirmed.</p><p>Pickup: <b>{{pickupTime}}</b> at {{pickupLocation}}.</p><p>Have a wonderful trip with DriveGo!</p></div>',
        speechScript: 'Hello {{customerName}}. Your DriveGo booking for {{vehicleName}} is confirmed for {{pickupTime}}.',
        dltTemplateId: '1107161234567890123',
        buttons: [{ type: 'URL', text: 'View Booking', payload: 'https://drivego.in/b/{{bookingId}}' }],
      },
      hi: {
        title: 'बुकिंग की पुष्टि हुई! 🚗',
        subject: 'आपकी DriveGo बुकिंग #{{bookingId}} स्वीकृत हो गई है',
        body: 'नमस्ते {{customerName}}, {{vehicleName}} (बुकिंग #{{bookingId}}) के लिए आपकी बुकिंग {{pickupLocation}} पर {{pickupTime}} के लिए सुनिश्चित हो गई है।',
        html: '<div style="font-family:sans-serif;"><h2>बुकिंग पक्की!</h2><p>नमस्ते <b>{{customerName}}</b>,</p><p>आपकी <b>{{vehicleName}}</b> बुकिंग (#{{bookingId}}) सफल रही।</p></div>',
        speechScript: 'नमस्ते {{customerName}}। आपकी DriveGo गाड़ी की बुकिंग सफल हो गई है।',
        dltTemplateId: '1107161234567890124',
      },
      te: {
        title: 'బుకింగ్ నిర్ధారించబడింది! 🚗',
        subject: 'మీ DriveGo బుకింగ్ #{{bookingId}} విజయవంతమైంది',
        body: 'నమస్కారం {{customerName}}, {{vehicleName}} కొరకు మీ బుకింగ్ (#{{bookingId}}) {{pickupTime}} వద్ద {{pickupLocation}} లో నిర్ధారించబడింది.',
        dltTemplateId: '1107161234567890125',
      },
      ta: {
        title: 'முன்பதிவு உறுதியானது! 🚗',
        subject: 'உங்கள் DriveGo முன்பதிவு #{{bookingId}} உறுதிசெய்யப்பட்டது',
        body: 'வணக்கம் {{customerName}}, {{vehicleName}} (#{{bookingId}}) முன்பதிவு {{pickupLocation}} இடத்தில் {{pickupTime}} மணிக்கு உறுதியானது.',
        dltTemplateId: '1107161234567890126',
      },
      kn: {
        title: 'ಬುಕಿಂಗ್ ದೃಢಪಟ್ಟಿದೆ! 🚗',
        subject: 'ನಿಮ್ಮ DriveGo ಬುಕಿಂಗ್ #{{bookingId}} ದೃಢಪಟ್ಟಿದೆ',
        body: 'ನಮಸ್ಕಾರ {{customerName}}, {{vehicleName}} (#{{bookingId}}) ಗಾಗಿ ನಿಮ್ಮ ಬುಕಿಂಗ್ {{pickupTime}} ಕ್ಕೆ ದೃಢಪಟ್ಟಿದೆ.',
        dltTemplateId: '1107161234567890127',
      },
      mr: {
        title: 'बुकिंग निश्चित झाली! 🚗',
        subject: 'तुमची DriveGo बुकिंग #{{bookingId}} कन्फर्म झाली आहे',
        body: 'नमस्कार {{customerName}}, तुमची {{vehicleName}} ची बुकिंग (#{{bookingId}}) {{pickupLocation}} येथे {{pickupTime}} साठी निश्चित झाली आहे.',
        dltTemplateId: '1107161234567890128',
      },
      es: {
        title: '¡Reserva Confirmada! 🚗',
        subject: 'Tu reserva DriveGo #{{bookingId}} está confirmada',
        body: 'Hola {{customerName}}, tu reserva de {{vehicleName}} (#{{bookingId}}) está confirmada para el {{pickupTime}} en {{pickupLocation}}.',
      },
      ar: {
        title: 'تم تأكيد الحجز! 🚗',
        subject: 'تم تأكيد حجزك في DriveGo رقم #{{bookingId}}',
        body: 'مرحباً {{customerName}}، تم تأكيد حجزك لسيارة {{vehicleName}} رقم ({{bookingId}}) للاستلام في {{pickupTime}}.',
      },
    },

    OTP_VERIFICATION: {
      en: {
        title: 'Your Verification Code',
        subject: '{{otpCode}} is your DriveGo Verification Code',
        body: '{{otpCode}} is your DriveGo verification code. Valid for 10 minutes. Please do not share this OTP with anyone.',
        html: '<div style="font-family:sans-serif; text-align:center;"><h2>DriveGo Security Verification</h2><p>Your OTP code is:</p><h1 style="color:#0284c7; letter-spacing:4px;">{{otpCode}}</h1><p>Valid for 10 minutes. Never share this code.</p></div>',
        speechScript: 'Your DriveGo security code is {{otpCode}}.',
        dltTemplateId: '1107161999999999001',
      },
      hi: {
        title: 'आपका सत्यापन कोड',
        subject: '{{otpCode}} आपका DriveGo ओटीपी है',
        body: '{{otpCode}} आपका DriveGo सुरक्षा कोड है। यह 10 मिनट के लिए मान्य है। इसे किसी के साथ साझा न करें।',
        dltTemplateId: '1107161999999999002',
      },
      te: {
        title: 'మీ ధృవీకరణ కోడ్',
        subject: '{{otpCode}} మీ DriveGo ఓటీపీ',
        body: '{{otpCode}} మీ DriveGo ధృవీకరణ కోడ్. 10 నిమిషాలు మాత్రమే చెల్లుతుంది. ఎవరితోనూ పంచుకోవద్దు.',
        dltTemplateId: '1107161999999999003',
      },
    },

    PICKUP_REMINDER: {
      en: {
        title: 'Rental Starts Soon! ⏰',
        subject: 'Reminder: Your DriveGo pickup is in {{etaMinutes}} mins',
        body: 'Hi {{customerName}}, your trip with {{vehicleName}} begins in {{etaMinutes}} minutes at {{pickupLocation}}. Please carry your original driving licence.',
        html: '<p>Hi <b>{{customerName}}</b>, your rental for <b>{{vehicleName}}</b> begins shortly at {{pickupLocation}}.</p>',
        speechScript: 'Reminder from DriveGo. Your vehicle {{vehicleName}} pickup is in {{etaMinutes}} minutes.',
        dltTemplateId: '1107161555555555001',
      },
      hi: {
        title: 'गाड़ी लेने का समय करीब है! ⏰',
        subject: 'याद दिलाएं: आपकी यात्रा {{etaMinutes}} मिनट में शुरू हो रही है',
        body: 'नमस्ते {{customerName}}, आपकी यात्रा {{etaMinutes}} मिनट में {{pickupLocation}} पर शुरू होगी। कृपया अपना मूल ड्राइविंग लाइसेंस साथ रखें।',
        dltTemplateId: '1107161555555555002',
      },
    },

    PAYMENT_SUCCESS: {
      en: {
        title: 'Payment Received ₹{{amount}} 💳',
        subject: 'Payment Successful: ₹{{amount}} for Booking #{{bookingId}}',
        body: 'Dear {{customerName}}, we have received your payment of ₹{{amount}} for booking #{{bookingId}}. Transaction ID: {{transactionId}}.',
        html: '<p>Dear <b>{{customerName}}</b>,</p><p>We received payment of <b>₹{{amount}}</b> for booking <code>{{bookingId}}</code>.</p>',
        dltTemplateId: '1107161777777777001',
      },
    },

    MARKETING_DISCOUNT: {
      en: {
        title: 'Special Weekend Offer! 🎉',
        subject: 'Get {{discountPercent}}% off on your next DriveGo roadtrip',
        body: 'Hey {{customerName}}, plan your weekend escape! Use code {{promoCode}} to get {{discountPercent}}% off on all SUV and sedan rentals.',
        html: '<div style="font-family:sans-serif;"><h2>Weekend Getaway Discount!</h2><p>Use code <b>{{promoCode}}</b> for {{discountPercent}}% off.</p></div>',
        dltTemplateId: '1107161888888888001',
      },
      hi: {
        title: 'सप्ताहांत विशेष छूट! 🎉',
        subject: 'अपनी अगली DriveGo यात्रा पर {{discountPercent}}% की छूट पाएं',
        body: 'नमस्ते {{customerName}}, कोड {{promoCode}} का उपयोग करके अपनी अगली यात्रा पर {{discountPercent}}% की छूट पाएं।',
        dltTemplateId: '1107161888888888002',
      },
    },
  };

  /**
   * Renders a communication template for a given channel and language.
   * Gracefully falls back to English if the requested language is unavailable.
   */
  renderTemplate(params: {
    channel: CommunicationChannel;
    templateName: string;
    language?: string;
    variables?: Record<string, string | number>;
  }): RenderedCommunication {
    const { channel, templateName, language = 'en', variables = {} } = params;
    const normLang = (language || 'en').toLowerCase().substring(0, 2);

    const templateGroup = this.templateRepository[templateName.toUpperCase()];
    if (!templateGroup) {
      this.logger.warn(`Template [${templateName}] not found in repository. Returning variable string fallback.`);
      return {
        channel,
        language: normLang,
        templateName,
        body: `Notification: ${JSON.stringify(variables)}`,
        variablesUsed: variables,
      };
    }

    // Resolve language or fallback to 'en'
    const langEntry = templateGroup[normLang] || templateGroup['en'] || Object.values(templateGroup)[0];
    const resolvedLang = templateGroup[normLang] ? normLang : 'en';

    // Interpolate variables with bidirectional format mapping (camelCase <-> dot.notation <-> snake_case)
    const interpolate = (text?: string): string => {
      if (!text) return '';
      return text.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (match, key) => {
        if (variables[key] !== undefined) return String(variables[key]);

        // If key is dot notation (e.g. customer.name) -> try camelCase (customerName)
        const camelKey = key.replace(/\.([a-z])/g, (_: string, l: string) => l.toUpperCase());
        if (variables[camelKey] !== undefined) return String(variables[camelKey]);

        // If key is camelCase (e.g. customerName) -> try dot notation (customer.name)
        const dotKey = key.replace(/([A-Z])/g, '.$1').toLowerCase();
        if (variables[dotKey] !== undefined) return String(variables[dotKey]);

        // Try snake_case (customer_name)
        const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase().replace(/\./g, '_');
        if (variables[snakeKey] !== undefined) return String(variables[snakeKey]);

        // Try loose matching by lowercase alpha-only
        const strippedKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
        for (const [vKey, vVal] of Object.entries(variables)) {
          if (vKey.toLowerCase().replace(/[^a-z0-9]/g, '') === strippedKey) {
            return String(vVal);
          }
        }

        return match;
      });
    };

    return {
      channel,
      language: resolvedLang,
      templateName,
      title: interpolate(langEntry.title),
      subject: interpolate(langEntry.subject),
      body: interpolate(langEntry.body),
      html: langEntry.html ? interpolate(langEntry.html) : undefined,
      speechScript: langEntry.speechScript ? interpolate(langEntry.speechScript) : undefined,
      dltTemplateId: langEntry.dltTemplateId,
      buttons: langEntry.buttons,
      variablesUsed: variables,
    };
  }

  getSupportedLanguages(templateName: string): string[] {
    const group = this.templateRepository[templateName.toUpperCase()];
    return group ? Object.keys(group) : ['en'];
  }

  hasTemplate(templateName: string): boolean {
    return !!this.templateRepository[templateName.toUpperCase()];
  }
}
