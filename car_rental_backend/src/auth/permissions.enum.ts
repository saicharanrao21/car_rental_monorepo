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
  VENDOR_REQUIREMENTS_READ = 'vendor_requirements:read',
  VENDOR_REQUIREMENTS_WRITE = 'vendor_requirements:write',
  VENDOR_DEPOSIT_READ = 'vendor_deposit:read',
  VENDOR_DEPOSIT_WRITE = 'vendor_deposit:write',
  VENDOR_VERIFICATION_READ = 'vendor_verification:read',
  VENDOR_VERIFICATION_WRITE = 'vendor_verification:write',
  FLEET_MANAGEMENT = 'fleet:management',
  FLEET_READ = 'fleet:read',
  FLEET_WRITE = 'fleet:write',
  FLEET_VERIFY = 'fleet:verify',

  // Location & Service Areas
  LOCATION_READ = 'location:read',
  LOCATION_WRITE = 'location:write',

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

  // Wallet
  WALLET_READ = 'wallet:read',
  WALLET_WRITE = 'wallet:write',
  WALLET_ADJUST = 'wallet:adjust',

  // Loyalty & Rewards
  LOYALTY_READ = 'loyalty:read',
  LOYALTY_WRITE = 'loyalty:write',
  LOYALTY_ADJUST = 'loyalty:adjust',

  // Support & Disputes
  SUPPORT_TICKET_READ = 'support:ticket:read',
  SUPPORT_TICKET_WRITE = 'support:ticket:write',
  DISPUTE_RESOLVE = 'dispute:resolve',

  // Growth & Marketing
  COUPON_MANAGE = 'coupon:manage',
  CAMPAIGN_MANAGE = 'campaign:manage',
  BANNER_MANAGE = 'banner:manage',
  REFERRAL_READ = 'referral:read',
  REFERRAL_WRITE = 'referral:write',

  // Risk & Fraud
  FRAUD_VIEW = 'fraud:view',
  FRAUD_RESOLVE = 'fraud:resolve',

  // Analytics & Control Tower
  ANALYTICS_READ = 'analytics:read',
  MARKETPLACE_INTELLIGENCE = 'marketplace:intelligence',
}

export enum StaffRole {
  SUPER_ADMIN = 'SUPER_ADMIN',
  OPERATIONS_MANAGER = 'OPERATIONS_MANAGER',
  CUSTOMER_SUPPORT = 'CUSTOMER_SUPPORT',
  FINANCE_MANAGER = 'FINANCE_MANAGER',
  MARKETING_MANAGER = 'MARKETING_MANAGER',
  COMPLIANCE_OFFICER = 'COMPLIANCE_OFFICER',
  READONLY_ANALYST = 'READONLY_ANALYST',
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
    AdminPermission.VENDOR_READ,
    AdminPermission.VENDOR_REQUIREMENTS_READ,
    AdminPermission.VENDOR_DEPOSIT_READ,
    AdminPermission.VENDOR_VERIFICATION_READ,
    AdminPermission.FLEET_READ,
  ],
  [Role.VENDOR]: [],
  [Role.CUSTOMER]: [],
};

export const STAFF_ROLE_PERMISSIONS_MATRIX: Record<StaffRole, AdminPermission[]> = {
  [StaffRole.SUPER_ADMIN]: Object.values(AdminPermission),
  [StaffRole.OPERATIONS_MANAGER]: [
    AdminPermission.VENDOR_READ,
    AdminPermission.VENDOR_WRITE,
    AdminPermission.VENDOR_REQUIREMENTS_READ,
    AdminPermission.VENDOR_REQUIREMENTS_WRITE,
    AdminPermission.VENDOR_DEPOSIT_READ,
    AdminPermission.VENDOR_VERIFICATION_READ,
    AdminPermission.VENDOR_VERIFICATION_WRITE,
    AdminPermission.FLEET_MANAGEMENT,
    AdminPermission.FLEET_READ,
    AdminPermission.FLEET_WRITE,
    AdminPermission.FLEET_VERIFY,
    AdminPermission.LOCATION_READ,
    AdminPermission.LOCATION_WRITE,
    AdminPermission.BOOKING_READ,
    AdminPermission.BOOKING_WRITE,
    AdminPermission.EMERGENCY_DISPATCH,
    AdminPermission.ANALYTICS_READ,
  ],
  [StaffRole.CUSTOMER_SUPPORT]: [
    AdminPermission.USER_READ,
    AdminPermission.BOOKING_READ,
    AdminPermission.BOOKING_WRITE,
    AdminPermission.SUPPORT_TICKET_READ,
    AdminPermission.SUPPORT_TICKET_WRITE,
    AdminPermission.EMERGENCY_DISPATCH,
    AdminPermission.DISPUTE_RESOLVE,
    AdminPermission.VENDOR_READ,
    AdminPermission.FLEET_READ,
  ],
  [StaffRole.FINANCE_MANAGER]: [
    AdminPermission.FINANCE_READ,
    AdminPermission.FINANCE_WRITE,
    AdminPermission.FINANCE_ADJUSTMENT,
    AdminPermission.PAYOUT_APPROVE,
    AdminPermission.PAYOUT_EXECUTE,
    AdminPermission.REFUND_ADJUDICATE,
    AdminPermission.DAMAGE_CLAIM_ADJUDICATE,
    AdminPermission.RECONCILIATION_READ,
    AdminPermission.RECONCILIATION_MANAGE,
    AdminPermission.COMMISSION_MANAGE,
    AdminPermission.WALLET_READ,
    AdminPermission.WALLET_WRITE,
    AdminPermission.WALLET_ADJUST,
    AdminPermission.VENDOR_DEPOSIT_READ,
    AdminPermission.VENDOR_DEPOSIT_WRITE,
    AdminPermission.BOOKING_READ,
    AdminPermission.ANALYTICS_READ,
  ],
  [StaffRole.MARKETING_MANAGER]: [
    AdminPermission.COUPON_MANAGE,
    AdminPermission.CAMPAIGN_MANAGE,
    AdminPermission.BANNER_MANAGE,
    AdminPermission.REFERRAL_READ,
    AdminPermission.REFERRAL_WRITE,
    AdminPermission.LOYALTY_READ,
    AdminPermission.LOYALTY_WRITE,
    AdminPermission.LOYALTY_ADJUST,
    AdminPermission.ANALYTICS_READ,
  ],
  [StaffRole.COMPLIANCE_OFFICER]: [
    AdminPermission.KYC_REVIEW,
    AdminPermission.VENDOR_REQUIREMENTS_READ,
    AdminPermission.VENDOR_REQUIREMENTS_WRITE,
    AdminPermission.VENDOR_VERIFICATION_READ,
    AdminPermission.VENDOR_VERIFICATION_WRITE,
    AdminPermission.VENDOR_DEPOSIT_READ,
    AdminPermission.DISPUTE_RESOLVE,
    AdminPermission.AUDIT_LOG_READ,
    AdminPermission.FRAUD_VIEW,
    AdminPermission.USER_READ,
    AdminPermission.VENDOR_READ,
  ],
  [StaffRole.READONLY_ANALYST]: [
    AdminPermission.ANALYTICS_READ,
    AdminPermission.MARKETPLACE_INTELLIGENCE,
    AdminPermission.AUDIT_LOG_READ,
    AdminPermission.BOOKING_READ,
    AdminPermission.VENDOR_READ,
    AdminPermission.FLEET_READ,
    AdminPermission.USER_READ,
    AdminPermission.FINANCE_READ,
    AdminPermission.RECONCILIATION_READ,
    AdminPermission.REFERRAL_READ,
    AdminPermission.LOYALTY_READ,
  ],
};

export function getPermissionsForUser(role: Role, staffRole?: string | null): AdminPermission[] {
  if (staffRole && (staffRole as StaffRole) in STAFF_ROLE_PERMISSIONS_MATRIX) {
    return STAFF_ROLE_PERMISSIONS_MATRIX[staffRole as StaffRole];
  }
  return ROLE_PERMISSIONS_MATRIX[role] || [];
}
