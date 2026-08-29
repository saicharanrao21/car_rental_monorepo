/**
 * DriveGo Redis Namespace Constants
 * Standardized key prefixing for 1M-user scalable multi-tenant caching, locking, and rate limiting.
 */
export const REDIS_NAMESPACES = {
  AUTH: {
    OTP_RATE_LIMIT: (phone: string) => `auth:otp:ratelimit:${phone}`,
    SESSION: (userId: string) => `auth:session:${userId}`,
    TOKEN_BLACKLIST: (tokenHash: string) => `auth:blacklist:${tokenHash}`,
  },
  LOCK: {
    CAR: (carId: string) => `lock:car:${carId}`,
    BOOKING: (bookingId: string) => `lock:booking:${bookingId}`,
    CANCEL_BOOKING: (bookingId: string) => `lock:cancel:booking:${bookingId}`,
    WALLET: (userId: string) => `lock:wallet:${userId}`,
    RECONCILIATION: () => `lock:cron:reconciliation`,
    CLEANUP: () => `lock:cron:cleanup`,
    GENERIC: (resource: string, id: string) => `lock:${resource}:${id}`,
  },
  CACHE: {
    SUPPORTED_CITIES: () => `cache:cities:all`,
    CITY_DETAIL: (city: string) => `cache:city:${city.toLowerCase()}`,
    CAR_SEARCH: (queryHash: string) => `cache:search:cars:${queryHash}`,
    CAR_DETAIL: (carId: string) => `cache:car:detail:${carId}`,
    SYSTEM_CONFIG: (key: string) => `cache:config:${key}`,
    PLATFORM_SETTINGS: () => `cache:settings:platform`,
    COMMISSION_CONFIG: (city: string, category: string, tripType: string) =>
      `cache:commission:${city.toLowerCase()}:${category}:${tripType}`,
    VENDOR_DETAIL: (vendorId: string) => `cache:vendor:detail:${vendorId}`,
  },
  RATE_LIMIT: {
    IP: (ip: string) => `ratelimit:ip:${ip}`,
    SEARCH: (ipOrUser: string) => `ratelimit:search:${ipOrUser}`,
    BOOKING_CREATION: (userId: string) => `ratelimit:booking:create:${userId}`,
    ADMIN_ACTION: (adminId: string) => `ratelimit:admin:${adminId}`,
  },
  IDEMPOTENCY: {
    KEY: (key: string) => `idempotency:${key}`,
  },
  QUEUE: {
    NOTIFICATIONS: 'notifications-queue',
    WEBHOOKS: 'webhooks-queue',
    RECONCILIATION: 'reconciliation-queue',
    CLEANUP: 'cleanup-queue',
    ANALYTICS: 'analytics-queue',
  },
} as const;

export const DEFAULT_CACHE_TTLS = {
  SHORT_TERM: 60, // 1 minute (dynamic pricing, search results)
  MEDIUM_TERM: 300, // 5 minutes (car catalog, platform settings)
  LONG_TERM: 3600, // 1 hour (supported cities, commission rates)
  EXTENDED: 86400, // 24 hours (static taxonomy, geographical bounds)
} as const;
