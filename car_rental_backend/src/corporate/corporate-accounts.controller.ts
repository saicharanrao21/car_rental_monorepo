import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  ParseBoolPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { CorporateAccountsService } from './corporate-accounts.service';
import {
  CreateCorporateAccountDto,
  UpdateCorporateAccountDto,
  ValidateCorporateCreditDto,
} from './dto/corporate-account.dto';

@Controller(['api/v1/corporate-accounts', 'corporate-accounts'])
@UseGuards(JwtAuthGuard, RolesGuard)
export class CorporateAccountsController {
  constructor(private readonly corporateService: CorporateAccountsService) {}

  @Post()
  @Roles(Role.ADMIN)
  async createAccount(@Body() dto: CreateCorporateAccountDto) {
    return this.corporateService.createAccount(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async listAccounts(
    @Query('isActive', new ParseBoolPipe({ optional: true })) isActive?: boolean,
    @Query('query') query?: string,
  ) {
    return this.corporateService.listAccounts({ isActive, query });
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getAccountById(@Param('id') id: string) {
    return this.corporateService.getAccountById(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  async updateAccount(
    @Param('id') id: string,
    @Body() dto: UpdateCorporateAccountDto,
  ) {
    return this.corporateService.updateAccount(id, dto);
  }

  @Post('validate-credit')
  @Roles(Role.CUSTOMER, Role.VENDOR, Role.ADMIN)
  async validateCredit(@Body() dto: ValidateCorporateCreditDto) {
    return this.corporateService.validateCredit(dto);
  }

  @Post('reserve-credit')
  @Roles(Role.CUSTOMER, Role.ADMIN)
  async reserveCredit(@Body() dto: ValidateCorporateCreditDto) {
    return this.corporateService.reserveCredit(
      dto.corporateCode,
      dto.estimatedAmount,
    );
  }

  @Post('release-credit')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async releaseCredit(@Body() dto: ValidateCorporateCreditDto) {
    return this.corporateService.releaseCredit(
      dto.corporateCode,
      dto.estimatedAmount,
    );
  }
}

