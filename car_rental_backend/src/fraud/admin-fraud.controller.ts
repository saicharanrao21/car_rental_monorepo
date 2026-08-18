import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { FraudService } from './fraud.service';
import { ResolveRiskAssessmentDto } from './dto/resolve-risk-assessment.dto';
import { RiskAssessmentQueryDto } from './dto/risk-assessment-query.dto';

@Controller('admin/fraud')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
export class AdminFraudController {
  constructor(private readonly fraudService: FraudService) {}

  @Get('summary')
  async getSummary() {
    return this.fraudService.getFraudSummary();
  }

  @Get('assessments')
  async getAssessments(@Query() query: RiskAssessmentQueryDto) {
    return this.fraudService.getRiskAssessments(query);
  }

  @Get('users/:userId/risk-profile')
  async getUserRiskProfile(@Param('userId') userId: string) {
    return this.fraudService.evaluateUserRisk(userId, {
      actionName: 'ADMIN_MANUAL_INSPECTION',
    });
  }

  @Post('assessments/:id/resolve')
  async resolveAssessment(
    @Req() req: any,
    @Param('id') assessmentId: string,
    @Body() dto: ResolveRiskAssessmentDto,
  ) {
    const userId = req.user.id || req.user.userId;
    return this.fraudService.resolveRiskAssessment(
      userId,
      assessmentId,
      dto,
    );
  }
}
