import { Controller, Get, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { VendorsService } from './vendors.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { UpdateDocumentStatusDto } from './dto/update-document-status.dto';
import { UpdateVendorSponsorshipDto } from './dto/update-vendor-sponsorship.dto';
import { VendorsQueryDto } from './dto/vendors-query.dto';
import { redactVendor } from '../common/vendor-redactor.util';

@Controller('admin/vendors')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminVendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @Get()
  async findAll(@Query() query: VendorsQueryDto) {
    const result = await this.vendorsService.findAll(query);
    result.data = result.data.map((vendor) => redactVendor(vendor, { isAdmin: true }));
    return result;
  }

  @Patch(':id/sponsorship')
  async updateSponsorship(
    @Param('id') id: string,
    @Body() dto: UpdateVendorSponsorshipDto,
  ) {
    return this.vendorsService.updateSponsorship(id, dto);
  }

  @Patch(':vendorId/documents/:id')
  async updateDocumentStatus(
    @Param('vendorId') vendorId: string,
    @Param('id') id: string,
    @Body() dto: UpdateDocumentStatusDto,
  ) {
    return this.vendorsService.updateDocumentStatus(vendorId, id, dto.status);
  }
}
