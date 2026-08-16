import { Module } from '@nestjs/common';
import { FareCalculatorService } from './fare-calculator.service';
import { CommissionResolverService } from './commission-resolver.service';
import { BankEncryptionService } from './bank-encryption.service';
import { ApmMonitoringService } from './apm-monitoring.service';

@Module({
  providers: [
    FareCalculatorService,
    CommissionResolverService,
    BankEncryptionService,
    ApmMonitoringService,
  ],
  exports: [
    FareCalculatorService,
    CommissionResolverService,
    BankEncryptionService,
    ApmMonitoringService,
  ],
})
export class CommonModule {}

