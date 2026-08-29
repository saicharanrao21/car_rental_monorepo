/**
 * DriveGo Background Job Queue Constants (BullMQ)
 */
export const QUEUE_NAMES = {
  NOTIFICATIONS: 'drivego-notifications-queue',
  WEBHOOKS: 'drivego-webhooks-queue',
  RECONCILIATION: 'drivego-reconciliation-queue',
  CLEANUP: 'drivego-cleanup-queue',
  ANALYTICS: 'drivego-analytics-queue',
} as const;

export const JOB_TYPES = {
  NOTIFICATIONS: {
    SEND_SMS: 'send-sms',
    SEND_EMAIL: 'send-email',
    SEND_PUSH: 'send-push',
    SEND_WHATSAPP: 'send-whatsapp',
  },
  WEBHOOKS: {
    PROCESS_RAZORPAY_PAYMENT: 'process-razorpay-payment',
    PROCESS_RAZORPAY_REFUND: 'process-razorpay-refund',
  },
  RECONCILIATION: {
    RUN_NIGHTLY_AUDIT: 'run-nightly-audit',
    RECONCILE_BOOKING: 'reconcile-booking',
  },
  CLEANUP: {
    PURGE_EXPIRED_OTPS: 'purge-expired-otps',
    EXPIRE_STALE_BOOKINGS: 'expire-stale-bookings',
    CLEAN_TEMP_STORAGE: 'clean-temp-storage',
  },
  ANALYTICS: {
    TRACK_EVENT: 'track-event',
    RECALCULATE_LOYALTY: 'recalculate-loyalty',
    EVALUATE_FRAUD_SIGNALS: 'evaluate-fraud-signals',
  },
} as const;

export const DEFAULT_JOB_OPTIONS = {
  attempts: 3,
  backoff: {
    type: 'exponential',
    delay: 2000, // 2s -> 4s -> 8s
  },
  removeOnComplete: {
    age: 86400, // Keep completed jobs for 24 hours
    count: 1000,
  },
  removeOnFail: {
    age: 604800, // Keep failed jobs for 7 days for audit/investigation
    count: 5000,
  },
} as const;
