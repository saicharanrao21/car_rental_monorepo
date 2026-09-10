import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  Req,
  UseGuards,
  ParseBoolPipe,
  ParseIntPipe,
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
  AddCorporateEmployeeDto,
  UpdateCorporateEmployeeStatusDto,
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
  async validateCredit(
    @Req() req: any,
    @Body() dto: ValidateCorporateCreditDto,
  ) {
    return this.corporateService.validateCredit(
      dto,
      req.user?.userId,
      req.user?.role,
    );
  }

  @Post('reserve-credit')
  @Roles(Role.CUSTOMER, Role.ADMIN)
  async reserveCredit(
    @Req() req: any,
    @Body() dto: ValidateCorporateCreditDto,
  ) {
    return this.corporateService.reserveCredit(
      dto.corporateCode,
      dto.estimatedAmount,
      req.user?.userId,
      req.user?.role,
    );
  }

  @Post('release-credit')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async releaseCredit(
    @Req() req: any,
    @Body() dto: ValidateCorporateCreditDto,
  ) {
    return this.corporateService.releaseCredit(
      dto.corporateCode,
      dto.estimatedAmount,
      req.user?.userId,
      req.user?.role,
    );
  }

  @Get(':id/employees')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async listEmployees(@Param('id') id: string) {
    return this.corporateService.listEmployees(id);
  }

  @Post(':id/employees')
  @Roles(Role.ADMIN)
  async addEmployee(
    @Param('id') id: string,
    @Body() dto: AddCorporateEmployeeDto,
  ) {
    return this.corporateService.addEmployee(id, dto);
  }

  @Patch(':id/employees/:employeeId/status')
  @Roles(Role.ADMIN)
  async updateEmployeeStatus(
    @Param('id') id: string,
    @Param('employeeId') employeeId: string,
    @Body() dto: UpdateCorporateEmployeeStatusDto,
  ) {
    return this.corporateService.updateEmployeeStatus(
      id,
      employeeId,
      dto.isActive,
    );
  }

  @Get(':id/credit-ledger')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getCreditLedger(
    @Param('id') id: string,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.corporateService.getCreditLedger(id, limit);
  }

  @Post(':id/settle-credit')
  @Roles(Role.ADMIN)
  async settleCredit(
    @Param('id') id: string,
    @Body() body: { amount: number; bookingId?: string },
    @Req() req: any,
  ) {
    const account = await this.corporateService.getAccountById(id);
    return this.corporateService.settleCredit(
      account.corporateCode,
      body.amount,
      req.user?.userId || req.user?.id,
      body.bookingId,
    );
  }

  @Get(':id/statement')
  @Roles(Role.ADMIN, Role.SUPPORT_AGENT)
  async getStatement(
    @Param('id') id: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    const start = startDate ? new Date(startDate) : undefined;
    const end = endDate ? new Date(endDate) : undefined;
    return this.corporateService.getStatement(id, start, end);
  }
}

