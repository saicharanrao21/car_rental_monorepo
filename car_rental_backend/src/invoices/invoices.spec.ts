import { Test, TestingModule } from '@nestjs/testing';
import { InvoicesService } from './invoices.service';
import { PrismaService } from '../prisma/prisma.service';
import { Role, Prisma, BookingStatus } from '@prisma/client';
import { ForbiddenException, NotFoundException } from '@nestjs/common';

describe('InvoicesService (Phase 3 Invoicing Engine)', () => {
  let service: InvoicesService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      invoice: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        create: jest.fn(),
      },
      booking: {
        findUnique: jest.fn(),
      },
      creditNote: {
        count: jest.fn(),
        create: jest.fn(),
      },
      platformSettings: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InvoicesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<InvoicesService>(InvoicesService);
  });

  describe('generateInvoiceForBooking', () => {
    it('creates a sequential tax invoice with complete fare breakdown', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_inv_1',
        customerId: 'cust_1',
        vendorId: 'vend_1',
        baseFare: new Prisma.Decimal(10000),
        platformFee: new Prisma.Decimal(1000),
        gstAmount: new Prisma.Decimal(180),
        discountAmount: new Prisma.Decimal(500),
        totalFare: new Prisma.Decimal(10680),
        securityDeposit: { amount: new Prisma.Decimal(5000) },
        payment: { id: 'pay_rec_1' },
        invoice: null,
      });

      prisma.invoice.count.mockResolvedValue(42);
      prisma.invoice.create.mockImplementation((args: any) =>
        Promise.resolve({ id: 'inv_1', ...args.data }),
      );

      const invoice = await service.generateInvoiceForBooking('book_inv_1');

      expect(invoice.invoiceNumber).toMatch(/^INV-\d{4}-\d{2}-00043$/);
      expect(invoice.bookingId).toBe('book_inv_1');
      expect(invoice.paymentId).toBe('pay_rec_1');
      expect(invoice.totalFare).toEqual(new Prisma.Decimal(10680));
      expect(invoice.depositAmount).toEqual(new Prisma.Decimal(5000));
      expect(prisma.invoice.create).toHaveBeenCalled();
    });

    it('returns existing invoice if already generated (idempotent)', async () => {
      const existingInvoice = {
        id: 'inv_existing',
        invoiceNumber: 'INV-2026-08-00010',
        bookingId: 'book_inv_2',
      };

      prisma.booking.findUnique.mockResolvedValue({
        id: 'book_inv_2',
        invoice: existingInvoice,
      });

      const res = await service.generateInvoiceForBooking('book_inv_2');
      expect(res).toBe(existingInvoice);
      expect(prisma.invoice.create).not.toHaveBeenCalled();
    });
  });

  describe('getInvoice authorization', () => {
    it('allows customer who owns the booking to access invoice', async () => {
      prisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_1',
        invoiceNumber: 'INV-2026-08-00001',
        customerId: 'cust_owner',
        booking: { vendorId: 'vendor_other' },
      });

      const res = await service.getInvoice('book_1', {
        userId: 'cust_owner',
        role: Role.CUSTOMER,
      });

      expect(res.invoiceNumber).toBe('INV-2026-08-00001');
    });

    it('denies unrelated customer from accessing invoice', async () => {
      prisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_1',
        invoiceNumber: 'INV-2026-08-00001',
        customerId: 'cust_owner',
        booking: { vendorId: 'vendor_other' },
      });

      await expect(
        service.getInvoice('book_1', {
          userId: 'cust_attacker',
          role: Role.CUSTOMER,
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows Admin to access any invoice', async () => {
      prisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_1',
        invoiceNumber: 'INV-2026-08-00001',
        customerId: 'cust_owner',
        booking: { vendorId: 'vendor_other' },
      });

      const res = await service.getInvoice('book_1', {
        userId: 'admin_1',
        role: Role.ADMIN,
      });

      expect(res.invoiceNumber).toBe('INV-2026-08-00001');
    });
  });

  describe('getInvoiceDocument (HTML template)', () => {
    it('generates HTML document containing GSTIN, CGST/SGST, and Refundable Deposit', async () => {
      prisma.invoice.findUnique.mockResolvedValue({
        id: 'inv_1',
        invoiceNumber: 'INV-2026-08-00001',
        customerId: 'cust_1',
        baseFare: new Prisma.Decimal(8000),
        platformFee: new Prisma.Decimal(800),
        gstAmount: new Prisma.Decimal(144),
        discountAmount: new Prisma.Decimal(0),
        totalFare: new Prisma.Decimal(8944),
        depositAmount: new Prisma.Decimal(5000),
        issuedAt: new Date('2026-08-16T10:00:00Z'),
        paymentId: 'pay_123',
        booking: {
          id: 'book_1',
          startDate: new Date('2026-08-20T10:00:00Z'),
          endDate: new Date('2026-08-22T10:00:00Z'),
          tripType: 'SELF_DRIVE',
          pickupLocation: 'Bandra West, Mumbai',
          vendorId: 'vend_1',
          customer: {
            name: 'John Doe',
            phone: '+919876543210',
            email: 'john@example.com',
          },
          vendor: {
            businessName: 'Royal Fleet',
            ownerName: 'Vikram Mehta',
            city: 'Mumbai',
            gstNumber: '27AABCU9603R1ZM',
          },
          car: {
            make: 'Hyundai',
            model: 'Creta',
            year: 2024,
            registrationNumber: 'MH02DW1234',
            category: 'SUV',
          },
        },
      });

      const doc = await service.getInvoiceDocument('book_1', {
        userId: 'cust_1',
        role: Role.CUSTOMER,
      });

      expect(doc.invoiceNumber).toBe('INV-2026-08-00001');
      expect(doc.html).toContain('DRIVEGO');
      expect(doc.html).toContain('27AAAAA1111A1Z1');
      expect(doc.html).toContain('John Doe');
      expect(doc.html).toContain('Royal Fleet');
      expect(doc.html).toContain('Hyundai Creta');
      expect(doc.html).toContain('Refundable Security Deposit Note');
    });
  });
});
