import { Role } from '@prisma/client';

export enum AdminPermission {
  // System & Platform
  SYSTEM_CONFIG_READ = 'system:config:read',
  SYSTEM_CONFIG_WRITE = 'system:config:write',
  AUDIT_LOG_READ = 'audit:log:read',

  // User & KYC
  USER_READ = 'user:read',
  USER_WRITE = 'user:write',
  KYC_REVIEW = 'kyc:review',

  // Vendor & Fleet
  VENDOR_READ = 'vendor:read',
  VENDOR_WRITE = 'vendor:write',
  FLEET_MANAGEMENT = 'fleet:management',

  // Bookings & Operations
  BOOKING_READ = 'booking:read',
  BOOKING_WRITE = 'booking:write',
  EMERGENCY_DISPATCH = 'emergency:dispatch',

  // Finance & Payouts
  FINANCE_READ = 'finance:read',
  FINANCE_WRITE = 'finance:write',
  FINANCE_ADJUSTMENT = 'finance:adjustment',
  PAYOUT_APPROVE = 'payout:approve',
  PAYOUT_EXECUTE = 'payout:execute',
  REFUND_ADJUDICATE = 'refund:adjudicate',
  DAMAGE_CLAIM_ADJUDICATE = 'damage_claim:adjudicate',
  RECONCILIATION_READ = 'reconciliation:read',
  RECONCILIATION_MANAGE = 'reconciliation:manage',
  COMMISSION_MANAGE = 'commission:manage',

  // Support & Disputes
  SUPPORT_TICKET_READ = 'support:ticket:read',
  SUPPORT_TICKET_WRITE = 'support:ticket:write',
  DISPUTE_RESOLVE = 'dispute:resolve',

  // Growth & Marketing
  COUPON_MANAGE = 'coupon:manage',
  CAMPAIGN_MANAGE = 'campaign:manage',
  BANNER_MANAGE = 'banner:manage',

  // Risk & Fraud
  FRAUD_VIEW = 'fraud:view',
  FRAUD_RESOLVE = 'fraud:resolve',

  // Analytics & Control Tower
  ANALYTICS_READ = 'analytics:read',
  MARKETPLACE_INTELLIGENCE = 'marketplace:intelligence',
}

export const ROLE_PERMISSIONS_MATRIX: Record<Role, AdminPermission[]> = {
  [Role.ADMIN]: Object.values(AdminPermission), // Full Super Admin access
  [Role.SUPPORT_AGENT]: [
    AdminPermission.USER_READ,
    AdminPermission.BOOKING_READ,
    AdminPermission.BOOKING_WRITE,
    AdminPermission.SUPPORT_TICKET_READ,
    AdminPermission.SUPPORT_TICKET_WRITE,
    AdminPermission.EMERGENCY_DISPATCH,
    AdminPermission.DISPUTE_RESOLVE,
  ],
  [Role.VENDOR]: [],
  [Role.CUSTOMER]: [],
};
