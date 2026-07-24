import { Controller, Get, Post, Body, Param, UseGuards, Req, HttpCode, HttpStatus } from '@nestjs/common';
import { DisputesService } from './disputes.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { AddEvidenceDto } from './dto/add-evidence.dto';

@Controller('disputes')
@UseGuards(JwtAuthGuard)
export class DisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async createDispute(@Req() req: any, @Body() dto: CreateDisputeDto) {
    return this.disputesService.createDispute(req.user.userId, dto);
  }

  @Post(':id/evidence')
  @HttpCode(HttpStatus.CREATED)
  async addEvidence(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: AddEvidenceDto,
  ) {
    return this.disputesService.addEvidence(req.user.userId, id, dto);
  }

  @Get(':id')
  async getDisputeById(@Req() req: any, @Param('id') id: string) {
    return this.disputesService.getDisputeById(req.user.userId, req.user.role, id);
  }
}
