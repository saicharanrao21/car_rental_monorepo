import { Module, forwardRef } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { FinancialReconciliationService } from './reconciliation.service';
import { EnterprisePaymentReconciliationService } from './enterprise-reconciliation.service';
import { CommonModule } from '../common/common.module';
import { InvoicesModule } from '../invoices/invoices.module';
import { WalletsModule } from '../wallets/wallets.module';

@Module({
  imports: [CommonModule, InvoicesModule, forwardRef(() => WalletsModule)],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    FinancialReconciliationService,
    EnterprisePaymentReconciliationService,
  ],
  exports: [
    PaymentsService,
    FinancialReconciliationService,
    EnterprisePaymentReconciliationService,
  ],
})
export class PaymentsModule {}

