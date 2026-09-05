/**
 * Phase 31: Canonical Operational Notification Templates
 * Multi-channel template engine supporting In-App, Push, SMS, WhatsApp, and Email.
 */

export interface TemplateVariables {
  customerName?: string;
  bookingId?: string;
  vehicleName?: string;
  registrationNumber?: string;
  pickupTime?: string;
  returnTime?: string;
  pickupAddress?: string;
  returnAddress?: string;
  deliveryFee?: string | number;
  paymentAmount?: string | number;
  refundAmount?: string | number;
  supportContact?: string;
  vendorName?: string;
  reason?: string;
  actionUrl?: string;
  [key: string]: any;
}

export interface RenderedNotificationPayload {
  title: string;
  body: string;
  smsText: string;
  whatsappTemplate: string;
  whatsappParams: string[];
  emailSubject: string;
  emailHtml: string;
  category: string;
  priority: 'HIGH' | 'NORMAL' | 'LOW';
  actionUrl?: string;
}

export type OperationalEventType =
  | 'BOOKING_CREATED'
  | 'BOOKING_CONFIRMED'
  | 'BOOKING_CANCELLED'
  | 'HANDOVER_READY'
  | 'TRIP_STARTED'
  | 'RETURN_PENDING'
  | 'BOOKING_COMPLETED'
  | 'PAYMENT_CAPTURED'
  | 'PAYMENT_FAILED'
  | 'REFUND_PENDING'
  | 'REFUND_PROCESSED'
  | 'REFUND_FAILED'
  | 'SETTLEMENT_ELIGIBLE'
  | 'ESCROW_HOLD_DISPUTED'
  | 'DOORSTEP_DISPATCHED'
  | 'DOORSTEP_ARRIVED';

function interpolate(template: string, vars: TemplateVariables): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    return vars[key] !== undefined && vars[key] !== null ? String(vars[key]) : '';
  });
}

export class NotificationTemplateEngine {
  static render(eventType: OperationalEventType, vars: TemplateVariables): RenderedNotificationPayload {
    const v: TemplateVariables = {
      customerName: vars.customerName || 'Valued Customer',
      bookingId: vars.bookingId || '',
      vehicleName: vars.vehicleName || 'Vehicle',
      supportContact: vars.supportContact || '+91 98765 43210',
      ...vars,
    };

    switch (eventType) {
      case 'BOOKING_CREATED':
        return {
          title: 'Booking Request Received',
          body: interpolate('Booking #{{bookingId}} for {{vehicleName}} is awaiting vendor confirmation.', v),
          smsText: interpolate('DriveGo: Your booking #{{bookingId}} for {{vehicleName}} is received and awaiting confirmation.', v),
          whatsappTemplate: 'booking_created',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!],
          emailSubject: interpolate('DriveGo Booking Request Received: #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Booking Request Received</h2><p>Dear {{customerName}},</p><p>We received your booking #{{bookingId}} for <strong>{{vehicleName}}</strong>. We are verifying availability with the host.</p><p>Support: {{supportContact}}</p>',
            v,
          ),
          category: 'BOOKING',
          priority: 'NORMAL',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'BOOKING_CONFIRMED':
        return {
          title: 'Booking Confirmed!',
          body: interpolate('Your rental for {{vehicleName}} is confirmed! Pickup on {{pickupTime}} at {{pickupAddress}}.', v),
          smsText: interpolate('DriveGo: Booking #{{bookingId}} CONFIRMED for {{vehicleName}}. Pickup: {{pickupTime}} at {{pickupAddress}}.', v),
          whatsappTemplate: 'booking_confirmed',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!, v.pickupTime || '', v.pickupAddress || '', v.paymentAmount ? `₹${v.paymentAmount}` : ''],
          emailSubject: interpolate('DriveGo Confirmed: Trip #{{bookingId}} — {{vehicleName}}', v),
          emailHtml: interpolate(
            '<h2>Trip Confirmed!</h2><p>Hi {{customerName}},</p><p>Your trip <strong>#{{bookingId}}</strong> with <strong>{{vehicleName}}</strong> is locked in.</p><ul><li><strong>Pickup:</strong> {{pickupTime}}</li><li><strong>Location:</strong> {{pickupAddress}}</li></ul><p>View your booking in the DriveGo app.</p>',
            v,
          ),
          category: 'BOOKING',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'BOOKING_CANCELLED':
        return {
          title: 'Booking Cancelled',
          body: interpolate('Booking #{{bookingId}} has been cancelled. Reason: {{reason}}.', v),
          smsText: interpolate('DriveGo: Booking #{{bookingId}} has been cancelled. {{reason}} Refund: {{refundAmount}}.', v),
          whatsappTemplate: 'booking_cancelled',
          whatsappParams: [v.customerName!, v.bookingId!, v.reason || 'Requested by customer', v.refundAmount ? `₹${v.refundAmount}` : '₹0'],
          emailSubject: interpolate('DriveGo Booking Cancelled: #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Booking Cancellation Notice</h2><p>Dear {{customerName}},</p><p>Booking #{{bookingId}} has been cancelled. Reason: {{reason}}.</p><p>Eligible refund amount: <strong>{{refundAmount}}</strong>.</p>',
            v,
          ),
          category: 'BOOKING',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'HANDOVER_READY':
        return {
          title: 'Vehicle Ready for Handover',
          body: interpolate('{{vehicleName}} is prepped and ready! Verify vehicle inspection manifest and share pickup OTP.', v),
          smsText: interpolate('DriveGo: {{vehicleName}} is ready for pickup! Complete vehicle inspection and share pickup OTP with host.', v),
          whatsappTemplate: 'handover_ready',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!, v.pickupAddress || 'Host Branch'],
          emailSubject: interpolate('Ready for Pickup: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Your Vehicle is Ready!</h2><p>Hi {{customerName}},</p><p>Your {{vehicleName}} is prepped at {{pickupAddress}}. Complete the digital inspection in your app to begin your drive.</p>',
            v,
          ),
          category: 'FULFILLMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'TRIP_STARTED':
        return {
          title: 'Trip Started — Drive Safely!',
          body: interpolate('Handover inspection verified for {{vehicleName}}. Trip #{{bookingId}} is now active.', v),
          smsText: interpolate('DriveGo: Trip #{{bookingId}} started! Drive safely. Return due by {{returnTime}}.', v),
          whatsappTemplate: 'trip_started',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!, v.returnTime || 'Scheduled Time'],
          emailSubject: interpolate('Trip Active: DriveGo #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Have a Great Drive!</h2><p>Dear {{customerName}},</p><p>Your rental for {{vehicleName}} is active. Please return by {{returnTime}} at {{returnAddress}}.</p>',
            v,
          ),
          category: 'TRIP',
          priority: 'NORMAL',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'RETURN_PENDING':
        return {
          title: 'Upcoming Return Reminder',
          body: interpolate('Trip #{{bookingId}} is due for return by {{returnTime}} at {{returnAddress}}.', v),
          smsText: interpolate('DriveGo Reminder: Vehicle return for #{{bookingId}} due by {{returnTime}} at {{returnAddress}}.', v),
          whatsappTemplate: 'trip_reminder',
          whatsappParams: [v.customerName!, v.bookingId!, v.returnTime || '', v.returnAddress || 'Designated Return Hub'],
          emailSubject: interpolate('Return Reminder: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Return Due Soon</h2><p>Hi {{customerName}},</p><p>Your rental is scheduled for return at {{returnTime}} at {{returnAddress}}. To extend, request an extension in the DriveGo app before return time.</p>',
            v,
          ),
          category: 'TRIP',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'BOOKING_COMPLETED':
        return {
          title: 'Trip Completed — Thank You!',
          body: interpolate('Return inspection completed for {{vehicleName}}. Your invoice and deposit release are ready.', v),
          smsText: interpolate('DriveGo: Trip #{{bookingId}} completed! Return inspection verified. Thank you for choosing DriveGo.', v),
          whatsappTemplate: 'booking_completed',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!],
          emailSubject: interpolate('Trip Completed: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Thank You for Driving with Us!</h2><p>Dear {{customerName}},</p><p>Trip #{{bookingId}} for {{vehicleName}} has officially concluded. Your receipt and final settlement summary are available in the app.</p>',
            v,
          ),
          category: 'BOOKING',
          priority: 'NORMAL',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'PAYMENT_CAPTURED':
        return {
          title: 'Payment Successful',
          body: interpolate('Payment of ₹{{paymentAmount}} captured successfully for booking #{{bookingId}}.', v),
          smsText: interpolate('DriveGo: Payment of Rs.{{paymentAmount}} received for booking #{{bookingId}}. Transaction confirmed.', v),
          whatsappTemplate: 'payment_successful',
          whatsappParams: [v.customerName!, v.bookingId!, String(v.paymentAmount || '0'), v.paymentId || 'Captured'],
          emailSubject: interpolate('Payment Receipt: ₹{{paymentAmount}} for #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Payment Receipt</h2><p>Dear {{customerName}},</p><p>We received your payment of <strong>₹{{paymentAmount}}</strong> for booking #{{bookingId}}.</p>',
            v,
          ),
          category: 'PAYMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'PAYMENT_FAILED':
        return {
          title: 'Payment Authorization Failed',
          body: interpolate('Payment for booking #{{bookingId}} could not be captured. Please retry safely to secure your car.', v),
          smsText: interpolate('DriveGo Alert: Payment failed for booking #{{bookingId}}. Please retry in the app to avoid cancellation.', v),
          whatsappTemplate: 'payment_failed',
          whatsappParams: [v.customerName!, v.bookingId!, v.reason || 'Declined by bank'],
          emailSubject: interpolate('Payment Failed: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Payment Action Required</h2><p>Dear {{customerName}},</p><p>We could not process payment for booking #{{bookingId}}. Your card has not been charged twice. Please re-attempt payment in the app.</p>',
            v,
          ),
          category: 'PAYMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'REFUND_PENDING':
        return {
          title: 'Refund Initiated',
          body: interpolate('A refund of ₹{{refundAmount}} has been initiated for booking #{{bookingId}}.', v),
          smsText: interpolate('DriveGo: Refund of Rs.{{refundAmount}} initiated for booking #{{bookingId}}. Processing via gateway.', v),
          whatsappTemplate: 'refund_pending',
          whatsappParams: [v.customerName!, v.bookingId!, String(v.refundAmount || '0')],
          emailSubject: interpolate('Refund Initiated: ₹{{refundAmount}} for #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Refund in Progress</h2><p>Dear {{customerName}},</p><p>Your refund of <strong>₹{{refundAmount}}</strong> has been submitted to the payment gateway and will reflect within 5-7 business days.</p>',
            v,
          ),
          category: 'PAYMENT',
          priority: 'NORMAL',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'REFUND_PROCESSED':
        return {
          title: 'Refund Credited Successfully',
          body: interpolate('₹{{refundAmount}} has been credited to your original payment instrument for booking #{{bookingId}}.', v),
          smsText: interpolate('DriveGo: Refund of Rs.{{refundAmount}} successfully processed and settled for booking #{{bookingId}}.', v),
          whatsappTemplate: 'refund_processed',
          whatsappParams: [v.customerName!, v.bookingId!, String(v.refundAmount || '0'), v.refundId || 'Settled'],
          emailSubject: interpolate('Refund Processed: ₹{{refundAmount}} Credited', v),
          emailHtml: interpolate(
            '<h2>Refund Settled</h2><p>Dear {{customerName}},</p><p>Your refund of <strong>₹{{refundAmount}}</strong> for booking #{{bookingId}} has been processed by your issuing bank.</p>',
            v,
          ),
          category: 'PAYMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'REFUND_FAILED':
        return {
          title: 'Refund Transfer Failed',
          body: interpolate('Automated refund of ₹{{refundAmount}} failed for booking #{{bookingId}}. Support team alerted.', v),
          smsText: interpolate('DriveGo Alert: Refund of Rs.{{refundAmount}} for booking #{{bookingId}} encountered an issue. Our support team is assisting.', v),
          whatsappTemplate: 'refund_failed',
          whatsappParams: [v.customerName!, v.bookingId!, String(v.refundAmount || '0')],
          emailSubject: interpolate('Notice: Refund Processing Issue for #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Refund Processing Notice</h2><p>Dear {{customerName}},</p><p>We encountered a technical issue transferring your refund of ₹{{refundAmount}}. Our finance team has been notified and will resolve this promptly.</p>',
            v,
          ),
          category: 'PAYMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'SETTLEMENT_ELIGIBLE':
        return {
          title: 'Vendor Settlement Eligible',
          body: interpolate('Booking #{{bookingId}} completed cleanly. Payout of ₹{{paymentAmount}} released from escrow.', v),
          smsText: interpolate('DriveGo Host: Booking #{{bookingId}} completed. Net settlement of Rs.{{paymentAmount}} is eligible for payout.', v),
          whatsappTemplate: 'settlement_eligible',
          whatsappParams: [v.vendorName || 'Host', v.bookingId!, String(v.paymentAmount || '0')],
          emailSubject: interpolate('Settlement Eligible: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Settlement Cleared</h2><p>Dear Partner,</p><p>Booking #{{bookingId}} completed with no dispute. Net settlement of <strong>₹{{paymentAmount}}</strong> is eligible for withdrawal.</p>',
            v,
          ),
          category: 'ESCROW',
          priority: 'NORMAL',
          actionUrl: '/earnings',
        };

      case 'ESCROW_HOLD_DISPUTED':
        return {
          title: 'Escrow Settlement Hold Placed',
          body: interpolate('Booking #{{bookingId}} has an active dispute/damage claim. Vendor settlement is on escrow hold.', v),
          smsText: interpolate('DriveGo Host: Settlement for #{{bookingId}} placed on hold due to active dispute/damage review.', v),
          whatsappTemplate: 'escrow_hold',
          whatsappParams: [v.vendorName || 'Host', v.bookingId!, v.reason || 'Damage or dispute under arbitration'],
          emailSubject: interpolate('Notice: Escrow Settlement Hold for #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Escrow Hold Notice</h2><p>Dear Partner,</p><p>A hold has been placed on settlement for booking #{{bookingId}} due to an active dispute or damage claim. Payout will remain quarantined until admin review concludes.</p>',
            v,
          ),
          category: 'ESCROW',
          priority: 'HIGH',
          actionUrl: '/earnings',
        };

      case 'DOORSTEP_DISPATCHED':
        return {
          title: 'Doorstep Valet Dispatched',
          body: interpolate('Your {{vehicleName}} is on the way! Valet has departed for {{pickupAddress}}.', v),
          smsText: interpolate('DriveGo: Valet dispatched with {{vehicleName}} to {{pickupAddress}} for booking #{{bookingId}}.', v),
          whatsappTemplate: 'doorstep_dispatch',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!, v.pickupAddress || ''],
          emailSubject: interpolate('Doorstep Delivery En Route: #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Your Car is on the Way!</h2><p>Dear {{customerName}},</p><p>Our delivery valet has departed with {{vehicleName}} for your doorstep at {{pickupAddress}}.</p>',
            v,
          ),
          category: 'FULFILLMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      case 'DOORSTEP_ARRIVED':
        return {
          title: 'Valet Arrived at Doorstep',
          body: interpolate('Valet has arrived with {{vehicleName}} at {{pickupAddress}}. Please verify inspection manifest and share OTP.', v),
          smsText: interpolate('DriveGo: Valet arrived with {{vehicleName}} at {{pickupAddress}}. Share pickup OTP to start drive.', v),
          whatsappTemplate: 'doorstep_arrived',
          whatsappParams: [v.customerName!, v.bookingId!, v.vehicleName!, v.pickupAddress || ''],
          emailSubject: interpolate('Valet Arrived: Booking #{{bookingId}}', v),
          emailHtml: interpolate(
            '<h2>Valet Has Arrived!</h2><p>Dear {{customerName}},</p><p>Your vehicle {{vehicleName}} has arrived at {{pickupAddress}}. Please present your pickup OTP to the valet to receive the keys.</p>',
            v,
          ),
          category: 'FULFILLMENT',
          priority: 'HIGH',
          actionUrl: v.actionUrl || `/my-bookings/${v.bookingId}`,
        };

      default:
        return {
          title: 'DriveGo Notification',
          body: interpolate('Update regarding booking #{{bookingId}}.', v),
          smsText: interpolate('DriveGo: Update regarding booking #{{bookingId}}.', v),
          whatsappTemplate: 'general_update',
          whatsappParams: [v.customerName!, v.bookingId!],
          emailSubject: 'DriveGo Notification',
          emailHtml: '<p>You have a new notification from DriveGo.</p>',
          category: 'GENERAL',
          priority: 'NORMAL',
          actionUrl: '/notifications',
        };
    }
  }
}
