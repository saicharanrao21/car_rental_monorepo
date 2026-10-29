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
import { PermissionsGuard } from '../auth/guards/permissions.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Role } from '@prisma/client';
import { AdminPermission } from '../auth/permissions.enum';
import { FraudService } from './fraud.service';
import { ResolveRiskAssessmentDto } from './dto/resolve-risk-assessment.dto';
import { RiskAssessmentQueryDto } from './dto/risk-assessment-query.dto';

@Controller('admin/fraud')
@UseGuards(JwtAuthGuard, RolesGuard, PermissionsGuard)
@Roles(Role.ADMIN)
export class AdminFraudController {
  constructor(private readonly fraudService: FraudService) {}

  @Get('summary')
  @RequirePermissions(AdminPermission.FRAUD_VIEW)
  async getSummary() {
    return this.fraudService.getFraudSummary();
  }

  @Get('assessments')
  @RequirePermissions(AdminPermission.FRAUD_VIEW)
  async getAssessments(@Query() query: RiskAssessmentQueryDto) {
    return this.fraudService.getRiskAssessments(query);
  }

  @Get('users/:userId/risk-profile')
  @RequirePermissions(AdminPermission.FRAUD_VIEW)
  async getUserRiskProfile(@Param('userId') userId: string) {
    return this.fraudService.evaluateUserRisk(userId, {
      actionName: 'ADMIN_MANUAL_INSPECTION',
    });
  }

  @Post('assessments/:id/resolve')
  @RequirePermissions(AdminPermission.FRAUD_RESOLVE)
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
