import { BookingStatus, Role } from '@prisma/client';

export type BookingLifecycleEventType =
  | 'BOOKING_CREATED'
  | 'BOOKING_CONFIRMED'
  | 'BOOKING_REJECTED'
  | 'BOOKING_CANCELLED'
  | 'HANDOVER_READY'
  | 'TRIP_STARTED'
  | 'RETURN_PENDING'
  | 'BOOKING_COMPLETED'
  | 'BOOKING_EXPIRED';

export type OutboxEventStatus = 'PENDING' | 'PUBLISHED' | 'FAILED' | 'DEAD_LETTER';

export interface BookingLifecyclePayload {
  bookingId: string;
  customerId: string;
  customerName?: string;
  customerPhone?: string;
  vendorId: string;
  vendorName?: string;
  vendorPhone?: string;
  carId: string;
  vehicleName: string;
  registrationNumber: string;
  startDate: string;
  endDate: string;
  totalFare: number;
  currency: string;
  pickupLocation: string;
  dropLocation?: string;
  cancellationReason?: string;
  cancellationFee?: number;
  refundAmount?: number;
  handoverOtpType?: string;
  odometerReading?: number;
  fuelPercent?: number;
  actionUrl?: string;
  metadata?: Record<string, any>;
}

export interface BookingTransitionContext {
  bookingId: string;
  actorId: string;
  actorRole: Role | 'SYSTEM';
  targetStatus: BookingStatus;
  reason?: string;
  handoverOtp?: string;
  metadata?: Record<string, any>;
}

export interface BookingTransitionResult {
  success: boolean;
  booking: any;
  outboxEventId: string;
  correlationId: string;
  previousStatus: BookingStatus;
  newStatus: BookingStatus;
  message?: string;
}

export interface BookingLifecycleHistoryItem {
  id: string;
  bookingId: string;
  eventType: string;
  actorId: string;
  actorRole: string;
  previousStatus: BookingStatus | null;
  newStatus: BookingStatus;
  correlationId: string;
  status: string;
  createdAt: Date;
  payload: Record<string, any>;
}
