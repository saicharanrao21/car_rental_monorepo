import { Module } from '@nestjs/common';
import { FareCalculatorService } from './fare-calculator.service';
import { CommissionResolverService } from './commission-resolver.service';
import { BankEncryptionService } from './bank-encryption.service';

@Module({
  providers: [
    FareCalculatorService,
    CommissionResolverService,
    BankEncryptionService,
  ],
  exports: [
    FareCalculatorService,
    CommissionResolverService,
    BankEncryptionService,
  ],
})
export class CommonModule {}

