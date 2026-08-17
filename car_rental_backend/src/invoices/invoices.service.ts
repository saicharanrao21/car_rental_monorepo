import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role, Prisma, BookingStatus } from '@prisma/client';

@Injectable()
export class InvoicesService {
  private readonly logger = new Logger(InvoicesService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Generates a sequential, immutable Tax Invoice for a confirmed booking.
   * Can be called inside an existing transaction or standalone.
   */
  async generateInvoiceForBooking(
    bookingId: string,
    tx?: Prisma.TransactionClient,
  ) {
    const db = tx || this.prisma;

    const booking = await db.booking.findUnique({
      where: { id: bookingId },
      include: {
        customer: true,
        vendor: true,
        car: true,
        payment: true,
        securityDeposit: true,
        invoice: true,
      },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found for invoice generation.');
    }

    if (booking.invoice) {
      return booking.invoice;
    }

    // Generate formatted invoice number: INV-YYYY-MM-XXXXX
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const count = await db.invoice.count();
    const sequence = String(count + 1).padStart(5, '0');
    const invoiceNumber = `INV-${year}-${month}-${sequence}`;

    const discountAmt = booking.discountAmount || new Prisma.Decimal(0);
    const depositAmt = booking.securityDeposit?.amount || new Prisma.Decimal(0);
    const paymentId = booking.payment?.id || 'PAY-PENDING';

    try {
      const invoice = await db.invoice.create({
        data: {
          invoiceNumber,
          bookingId: booking.id,
          paymentId,
          customerId: booking.customerId,
          vendorId: booking.vendorId,
          baseFare: booking.baseFare,
          platformFee: booking.platformFee,
          protectionFee: booking.protectionFee || new Prisma.Decimal(0),
          gstRate: new Prisma.Decimal(18.0),
          gstAmount: booking.gstAmount,
          discountAmount: discountAmt,
          totalFare: booking.totalFare,
          depositAmount: depositAmt,
          issuedAt: new Date(),
        },
      });

      this.logger.log(
        `Generated tax invoice ${invoiceNumber} for booking ${bookingId}`,
      );
      return invoice;
    } catch (err: any) {
      if (err.code === 'P2002') {
        // Unique constraint violation (invoice already exists concurrently)
        return db.invoice.findUnique({ where: { bookingId } });
      }
      throw err;
    }
  }

  /**
   * Retrieves an invoice with RBAC validation.
   */
  async getInvoice(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { bookingId },
      include: {
        booking: {
          include: {
            customer: {
              select: { id: true, name: true, phone: true, email: true },
            },
            vendor: {
              select: {
                id: true,
                businessName: true,
                ownerName: true,
                city: true,
                gstNumber: true,
              },
            },
            car: {
              select: {
                id: true,
                make: true,
                model: true,
                year: true,
                registrationNumber: true,
                type: true,
              },
            },
            payment: true,
            securityDeposit: true,
          },
        },
        creditNotes: true,
      },
    });

    if (!invoice) {
      // If booking is confirmed/completed but invoice not yet recorded, attempt generation
      const booking = await this.prisma.booking.findUnique({
        where: { id: bookingId },
        include: { payment: true },
      });

      if (
        booking &&
        booking.status !== BookingStatus.PENDING &&
        booking.status !== BookingStatus.CANCELLED
      ) {
        return this.generateInvoiceForBooking(bookingId);
      }

      throw new NotFoundException('Tax invoice not found for this booking.');
    }

    const isAdmin = requestingUser.role === Role.ADMIN;
    const isSupport = requestingUser.role === Role.SUPPORT_AGENT;
    const isCustomer = invoice.customerId === requestingUser.userId;
    const isVendor = invoice.vendorId === requestingUser.userId;

    if (!isAdmin && !isSupport && !isCustomer && !isVendor) {
      throw new ForbiddenException(
        'Access denied: You are not authorized to view this tax invoice.',
      );
    }

    return invoice;
  }

  /**
   * Generates a printable, GST-compliant HTML/PDF tax invoice and receipt.
   */
  async getInvoiceDocument(
    bookingId: string,
    requestingUser: { userId: string; role: Role },
  ): Promise<{ html: string; invoiceNumber: string }> {
    const invoice: any = await this.getInvoice(bookingId, requestingUser);
    const b = invoice.booking;

    // Fetch dynamic platform business configuration with fallback
    const platformSettings = await this.prisma.platformSettings?.findFirst?.().catch(() => null);
    const companyGstin = process.env.COMPANY_GSTIN || platformSettings?.gstNumber || '27AAAAA1111A1Z1';
    const companyPan = process.env.COMPANY_PAN || 'AAAAA1111A';
    const supportEmail = platformSettings?.supportEmail || process.env.SUPPORT_EMAIL || 'support@drivego.in';
    const supportPhone = platformSettings?.supportPhone || process.env.SUPPORT_PHONE || '+91 1800-200-3000';

    const baseFareFormatted = Number(invoice.baseFare).toLocaleString('en-IN', {
      maximumFractionDigits: 2,
    });
    const platformFeeFormatted = Number(invoice.platformFee).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );
    const gstFormatted = Number(invoice.gstAmount).toLocaleString('en-IN', {
      maximumFractionDigits: 2,
    });
    const discountFormatted = Number(invoice.discountAmount).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );
    const totalFareFormatted = Number(invoice.totalFare).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );
    const depositFormatted = Number(invoice.depositAmount).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );
    const grandTotalFormatted = (
      Number(invoice.totalFare) + Number(invoice.depositAmount)
    ).toLocaleString('en-IN', { maximumFractionDigits: 2 });

    const cgstFormatted = (Number(invoice.gstAmount) / 2).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );
    const sgstFormatted = (Number(invoice.gstAmount) / 2).toLocaleString(
      'en-IN',
      { maximumFractionDigits: 2 },
    );

    const issuedDate = new Date(invoice.issuedAt).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

    const tripStart = new Date(b.startDate).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const tripEnd = new Date(b.endDate).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Tax Invoice - ${invoice.invoiceNumber}</title>
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 40px; color: #1a1a1a; background: #fff; line-height: 1.5; }
    .invoice-card { max-width: 800px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; padding: 36px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #2563eb; padding-bottom: 20px; }
    .brand { font-size: 28px; font-weight: 800; color: #2563eb; letter-spacing: -0.5px; }
    .brand-sub { font-size: 12px; color: #64748b; margin-top: 2px; }
    .invoice-title { text-align: right; }
    .invoice-title h1 { margin: 0; font-size: 20px; color: #1e293b; text-transform: uppercase; }
    .invoice-meta { font-size: 13px; color: #64748b; margin-top: 4px; }
    .parties { display: flex; justify-content: space-between; margin-top: 28px; font-size: 13px; }
    .party-col { width: 48%; }
    .party-title { font-weight: 700; color: #0f172a; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px; margin-bottom: 8px; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }
    .trip-box { margin-top: 24px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 14px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; font-size: 12px; }
    .trip-box div strong { display: block; color: #475569; font-size: 11px; text-transform: uppercase; margin-bottom: 2px; }
    table.line-items { width: 100%; border-collapse: collapse; margin-top: 24px; font-size: 13px; }
    table.line-items th { background: #f1f5f9; text-align: left; padding: 10px 12px; font-weight: 600; color: #334155; border-bottom: 1px solid #cbd5e1; }
    table.line-items td { padding: 10px 12px; border-bottom: 1px solid #e2e8f0; }
    table.line-items td.num { text-align: right; }
    table.line-items th.num { text-align: right; }
    .summary-section { display: flex; justify-content: flex-end; margin-top: 20px; }
    .summary-table { width: 340px; font-size: 13px; border-collapse: collapse; }
    .summary-table td { padding: 6px 10px; }
    .summary-table td.num { text-align: right; }
    .summary-table tr.total-row td { font-weight: 800; font-size: 15px; border-top: 2px solid #0f172a; color: #0f172a; padding-top: 10px; }
    .deposit-badge { background: #eff6ff; border-left: 4px solid #3b82f6; padding: 12px; border-radius: 4px; margin-top: 20px; font-size: 12px; color: #1e40af; }
    .footer { margin-top: 36px; padding-top: 16px; border-top: 1px dashed #cbd5e1; font-size: 11px; color: #94a3b8; text-align: center; }
  </style>
</head>
<body>
  <div class="invoice-card">
    <div class="header">
      <div>
        <div class="brand">DRIVEGO</div>
        <div class="brand-sub">Premium Car Rental & Self-Drive Solutions</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 6px;">
          GSTIN: ${companyGstin} | PAN: ${companyPan}<br>
          Support: ${supportEmail} | ${supportPhone}
        </div>
      </div>
      <div class="invoice-title">
        <h1>Tax Invoice / Receipt</h1>
        <div class="invoice-meta"><strong>Invoice #:</strong> ${invoice.invoiceNumber}</div>
        <div class="invoice-meta"><strong>Date:</strong> ${issuedDate}</div>
        <div class="invoice-meta"><strong>Booking ID:</strong> ${b.id}</div>
        <div class="invoice-meta"><strong>Payment ID:</strong> ${invoice.paymentId}</div>
      </div>
    </div>

    <div class="parties">
      <div class="party-col">
        <div class="party-title">Billed To (Customer)</div>
        <strong>${b.customer.name}</strong><br>
        Phone: ${b.customer.phone}<br>
        Email: ${b.customer.email || 'N/A'}<br>
        Pickup City: ${b.vendor.city}
      </div>
      <div class="party-col">
        <div class="party-title">Fleet Partner (Vendor)</div>
        <strong>${b.vendor.businessName}</strong><br>
        Owner: ${b.vendor.ownerName}<br>
        City: ${b.vendor.city}<br>
        ${b.vendor.gstNumber ? `Vendor GSTIN: ${b.vendor.gstNumber}` : 'Vendor: Unregistered Small Enterprise'}
      </div>
    </div>

    <div class="trip-box">
      <div>
        <strong>Vehicle Booked</strong>
        ${b.car.make} ${b.car.model} (${b.car.year})<br>
        <span style="color: #64748b;">Reg: ${b.car.registrationNumber} (${b.car.type || b.car.category || 'Sedan'})</span>
      </div>
      <div>
        <strong>Trip Period</strong>
        ${tripStart}<br>to ${tripEnd}
      </div>
      <div>
        <strong>Trip Type & Route</strong>
        ${b.tripType}<br>
        <span style="color: #64748b;">${b.pickupLocation}</span>
      </div>
    </div>

    <table class="line-items">
      <thead>
        <tr>
          <th>Description</th>
          <th style="width: 80px;">HSN/SAC</th>
          <th class="num" style="width: 120px;">Amount (₹)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <strong>Vehicle Rental Base Fare</strong><br>
            <span style="font-size: 11px; color: #64748b;">Self-drive rental package charges</span>
          </td>
          <td>996601</td>
          <td class="num">${baseFareFormatted}</td>
        </tr>
        <tr>
          <td>
            <strong>Platform Service Fee</strong><br>
            <span style="font-size: 11px; color: #64748b;">Technology platform facilitation fee</span>
          </td>
          <td>998313</td>
          <td class="num">${platformFeeFormatted}</td>
        </tr>
        ${
          Number(invoice.discountAmount) > 0
            ? `<tr>
                <td style="color: #15803d;"><strong>Promotional Coupon Discount</strong></td>
                <td>-</td>
                <td class="num" style="color: #15803d;">- ₹${discountFormatted}</td>
              </tr>`
            : ''
        }
        <tr>
          <td><strong>CGST (9% on Platform Fee)</strong></td>
          <td>998313</td>
          <td class="num">${cgstFormatted}</td>
        </tr>
        <tr>
          <td><strong>SGST (9% on Platform Fee)</strong></td>
          <td>998313</td>
          <td class="num">${sgstFormatted}</td>
        </tr>
      </tbody>
    </table>

    <div class="summary-section">
      <table class="summary-table">
        <tr>
          <td>Trip Rental Fare:</td>
          <td class="num">₹${totalFareFormatted}</td>
        </tr>
        <tr>
          <td>Refundable Security Deposit:</td>
          <td class="num">₹${depositFormatted}</td>
        </tr>
        <tr class="total-row">
          <td>Total Paid (INR):</td>
          <td class="num">₹${grandTotalFormatted}</td>
        </tr>
      </table>
    </div>

    <div class="deposit-badge">
      <strong>Refundable Security Deposit Note:</strong><br>
      The security deposit of ₹${depositFormatted} is held in escrow and is 100% refundable upon vehicle return inspection verification. Security deposit is an escrow hold and is not subject to GST.
    </div>

    <div class="footer">
      This is a computer-generated tax invoice and does not require a physical signature.<br>
      DriveGo Mobility Technologies Pvt. Ltd. • Registered Office: Mumbai, Maharashtra, India.
    </div>
  </div>
</body>
</html>`;

    return { html, invoiceNumber: invoice.invoiceNumber };
  }

  /**
   * Retrieves all invoices for the Admin Panel.
   */
  async getAllInvoicesForAdmin(query: {
    search?: string;
    startDate?: string;
    endDate?: string;
    page?: number;
    limit?: number;
  }) {
    const page = query.page || 1;
    const limit = query.limit || 50;
    const skip = (page - 1) * limit;

    const where: any = {};

    if (query.search) {
      where.OR = [
        { invoiceNumber: { contains: query.search, mode: 'insensitive' } },
        { bookingId: { contains: query.search, mode: 'insensitive' } },
        {
          customer: {
            name: { contains: query.search, mode: 'insensitive' },
          },
        },
        {
          vendor: {
            businessName: { contains: query.search, mode: 'insensitive' },
          },
        },
      ];
    }

    if (query.startDate || query.endDate) {
      where.issuedAt = {};
      if (query.startDate) where.issuedAt.gte = new Date(query.startDate);
      if (query.endDate) where.issuedAt.lte = new Date(query.endDate);
    }

    const [invoices, total] = await Promise.all([
      this.prisma.invoice.findMany({
        where,
        orderBy: { issuedAt: 'desc' },
        skip,
        take: limit,
        include: {
          customer: {
            select: { id: true, name: true, phone: true, email: true },
          },
          vendor: {
            select: { id: true, businessName: true, city: true },
          },
          booking: {
            select: { id: true, status: true, tripType: true },
          },
        },
      }),
      this.prisma.invoice.count({ where }),
    ]);

    return {
      invoices,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Generates a Credit Note for cancellation refunds or post-trip adjustments.
   */
  async createCreditNote(
    invoiceId: string,
    amount: number,
    reason: string,
    tx?: Prisma.TransactionClient,
  ) {
    const db = tx || this.prisma;

    const invoice = await db.invoice.findUnique({
      where: { id: invoiceId },
    });

    if (!invoice) {
      throw new NotFoundException('Invoice not found.');
    }

    const now = new Date();
    const count = await db.creditNote.count();
    const sequence = String(count + 1).padStart(5, '0');
    const creditNoteNumber = `CN-${now.getFullYear()}-${String(
      now.getMonth() + 1,
    ).padStart(2, '0')}-${sequence}`;

    return db.creditNote.create({
      data: {
        creditNoteNumber,
        invoiceId,
        bookingId: invoice.bookingId,
        amount: new Prisma.Decimal(amount),
        reason,
        issuedAt: new Date(),
      },
    });
  }
}
