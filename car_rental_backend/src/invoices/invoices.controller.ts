import {
  Controller,
  Get,
  Param,
  Query,
  Res,
  UseGuards,
  Request,
} from '@nestjs/common';
import type { Response } from 'express';
import { InvoicesService } from './invoices.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class InvoicesController {
  constructor(private readonly invoicesService: InvoicesService) {}

  @Get('bookings/:id/invoice')
  async getInvoice(@Param('id') bookingId: string, @Request() req: any) {
    return this.invoicesService.getInvoice(bookingId, req.user);
  }

  @Get('bookings/:id/invoice/download')
  async downloadInvoice(
    @Param('id') bookingId: string,
    @Request() req: any,
    @Res() res: Response,
  ) {
    const { html, invoiceNumber } =
      await this.invoicesService.getInvoiceDocument(bookingId, req.user);

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `inline; filename="Tax_Invoice_${invoiceNumber}.html"`,
    );
    return res.send(html);
  }

  @Get('admin/invoices')
  @Roles(Role.ADMIN)
  async getAllInvoices(
    @Query('search') search?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.invoicesService.getAllInvoicesForAdmin({
      search,
      startDate,
      endDate,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 50,
    });
  }
}
