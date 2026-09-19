import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminExportService {
  constructor(private readonly prisma: PrismaService) {}

  private escapeCsv(val: any): string {
    if (val === null || val === undefined) return '';
    const str = String(val);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  }

  async exportBookingsCsv(startDate?: Date, endDate?: Date): Promise<string> {
    const where: any = {};
    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = startDate;
      if (endDate) where.createdAt.lte = endDate;
    }

    const bookings = await this.prisma.booking.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        customer: { select: { name: true, phone: true, email: true } },
        vendor: { select: { businessName: true } },
        car: { select: { make: true, model: true, registrationNumber: true } },
        securityDeposit: { select: { amount: true } },
      },
      take: 5000,
    });

    const headers = [
      'Booking ID',
      'Reference Code',
      'Customer Name',
      'Customer Phone',
      'Vendor Business',
      'Vehicle',
      'Registration Plate',
      'Status',
      'Total Fare (INR)',
      'Security Deposit (INR)',
      'Start Date',
      'End Date',
      'Created At',
    ];

    const rows = bookings.map((b) => [
      this.escapeCsv(b.id),
      this.escapeCsv(b.id.slice(-8).toUpperCase()),
      this.escapeCsv(b.customer?.name),
      this.escapeCsv(b.customer?.phone),
      this.escapeCsv(b.vendor?.businessName),
      this.escapeCsv(`${b.car?.make || ''} ${b.car?.model || ''}`.trim()),
      this.escapeCsv(b.car?.registrationNumber),
      this.escapeCsv(b.status),
      this.escapeCsv(b.totalFare),
      this.escapeCsv(b.securityDeposit?.amount || 0),
      this.escapeCsv(b.startDate?.toISOString()),
      this.escapeCsv(b.endDate?.toISOString()),
      this.escapeCsv(b.createdAt?.toISOString()),
    ]);

    return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
  }

  async exportPaymentsCsv(startDate?: Date, endDate?: Date): Promise<string> {
    const where: any = {};
    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = startDate;
      if (endDate) where.createdAt.lte = endDate;
    }

    const payments = await this.prisma.payment.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        booking: { select: { id: true } },
      },
      take: 5000,
    });

    const headers = [
      'Payment ID',
      'Booking ID',
      'Razorpay Order ID',
      'Razorpay Payment ID',
      'Amount (INR)',
      'Status',
      'Refund Status',
      'Payment Method',
      'Captured At',
      'Created At',
    ];

    const rows = payments.map((p) => [
      this.escapeCsv(p.id),
      this.escapeCsv(p.booking?.id || p.bookingId),
      this.escapeCsv(p.razorpayOrderId),
      this.escapeCsv(p.razorpayPaymentId),
      this.escapeCsv(p.amount),
      this.escapeCsv(p.status),
      this.escapeCsv(p.refundStatus),
      this.escapeCsv(p.paymentMethod),
      this.escapeCsv(p.capturedAt?.toISOString()),
      this.escapeCsv(p.createdAt?.toISOString()),
    ]);

    return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
  }

  async exportVendorsCsv(): Promise<string> {
    const vendors = await this.prisma.vendor.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { phone: true, email: true } },
      },
      take: 2000,
    });

    const headers = [
      'Vendor ID',
      'Business Name',
      'Owner Name',
      'City',
      'Contact Phone',
      'GST Number',
      'Verification Status',
      'Rating',
      'Active Fleet Count',
      'Created At',
    ];

    const rows = vendors.map((v) => [
      this.escapeCsv(v.id),
      this.escapeCsv(v.businessName),
      this.escapeCsv(v.ownerName),
      this.escapeCsv(v.city),
      this.escapeCsv(v.user?.phone),
      this.escapeCsv(v.gstNumber),
      this.escapeCsv(v.verificationStatus),
      this.escapeCsv(v.rating),
      this.escapeCsv(0),
      this.escapeCsv(v.createdAt?.toISOString()),
    ]);

    return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
  }

  async exportData(entity: string, start?: string, end?: string): Promise<{ filename: string; csv: string }> {
    const startDate = start ? new Date(start) : undefined;
    const endDate = end ? new Date(end) : undefined;

    if (startDate && isNaN(startDate.getTime())) {
      throw new BadRequestException('Invalid startDate');
    }
    if (endDate && isNaN(endDate.getTime())) {
      throw new BadRequestException('Invalid endDate');
    }

    const timestamp = new Date().toISOString().slice(0, 10);
    const upper = (entity || '').toUpperCase();

    switch (upper) {
      case 'BOOKINGS':
        return {
          filename: `drivego_bookings_${timestamp}.csv`,
          csv: await this.exportBookingsCsv(startDate, endDate),
        };
      case 'PAYMENTS':
        return {
          filename: `drivego_payments_${timestamp}.csv`,
          csv: await this.exportPaymentsCsv(startDate, endDate),
        };
      case 'VENDORS':
        return {
          filename: `drivego_vendors_${timestamp}.csv`,
          csv: await this.exportVendorsCsv(),
        };
      default:
        throw new BadRequestException(`Unknown export entity: ${entity}. Supported: BOOKINGS, PAYMENTS, VENDORS`);
    }
  }
}
