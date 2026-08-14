import { Injectable, LoggerService, LogLevel } from '@nestjs/common';

const SENSITIVE_PATTERNS = [
  /Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*/gi,
  /password["':\s]+["']?([^"',\s]+)/gi,
  /otp["':\s]+["']?(\d{6})/gi,
  /rawOtp["':\s]+["']?(\d{6})/gi,
  /keySecret["':\s]+["']?([^"',\s]+)/gi,
  /webhookSecret["':\s]+["']?([^"',\s]+)/gi,
  /BANK_ENCRYPTION_KEY["':\s]+["']?([^"',\s]+)/gi,
];

@Injectable()
export class StructuredLoggerService implements LoggerService {
  private logLevels: LogLevel[] = ['log', 'error', 'warn', 'debug', 'verbose'];

  setLogLevels(levels: LogLevel[]) {
    this.logLevels = levels;
  }

  private redact(message: string): string {
    let sanitized = message;
    for (const pattern of SENSITIVE_PATTERNS) {
      sanitized = sanitized.replace(pattern, (match) => {
        if (match.startsWith('Bearer')) return 'Bearer [REDACTED]';
        return match.replace(/:.*/, ': "[REDACTED]"');
      });
    }
    return sanitized;
  }

  private formatMessage(
    level: string,
    message: any,
    context?: string,
    trace?: string,
  ): string {
    const rawMsg = typeof message === 'object' ? JSON.stringify(message) : String(message);
    const sanitizedMsg = this.redact(rawMsg);

    if (process.env.NODE_ENV === 'production') {
      const entry: Record<string, any> = {
        timestamp: new Date().toISOString(),
        level: level.toUpperCase(),
        context: context || 'Application',
        message: sanitizedMsg,
      };
      if (trace) entry.trace = trace;
      return JSON.stringify(entry);
    }

    const contextStr = context ? `[${context}] ` : '';
    return `${new Date().toLocaleTimeString()} ${level.toUpperCase().padEnd(7)} ${contextStr}${sanitizedMsg}${trace ? `\n${trace}` : ''}`;
  }

  log(message: any, context?: string) {
    if (!this.logLevels.includes('log')) return;
    console.log(this.formatMessage('log', message, context));
  }

  error(message: any, trace?: string, context?: string) {
    if (!this.logLevels.includes('error')) return;
    console.error(this.formatMessage('error', message, context, trace));
  }

  warn(message: any, context?: string) {
    if (!this.logLevels.includes('warn')) return;
    console.warn(this.formatMessage('warn', message, context));
  }

  debug(message: any, context?: string) {
    if (!this.logLevels.includes('debug')) return;
    console.debug(this.formatMessage('debug', message, context));
  }

  verbose(message: any, context?: string) {
    if (!this.logLevels.includes('verbose')) return;
    console.log(this.formatMessage('verbose', message, context));
  }
}
