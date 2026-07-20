import { Controller, Patch, Body, Param, UseGuards } from '@nestjs/common';
import { VendorsService } from './vendors.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { UpdateDocumentStatusDto } from './dto/update-document-status.dto';

@Controller('admin/vendors')
export class AdminVendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.ADMIN)
  @Patch(':vendorId/documents/:id')
  async updateDocumentStatus(
    @Param('vendorId') vendorId: string,
    @Param('id') id: string,
    @Body() dto: UpdateDocumentStatusDto,
  ) {
    return this.vendorsService.updateDocumentStatus(vendorId, id, dto.status);
  }
}
