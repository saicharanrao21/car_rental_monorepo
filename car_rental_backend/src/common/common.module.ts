import { Module } from '@nestjs/common';
import { FareCalculatorService } from './fare-calculator.service';
import { CommissionResolverService } from './commission-resolver.service';

@Module({
  providers: [FareCalculatorService, CommissionResolverService],
  exports: [FareCalculatorService, CommissionResolverService],
})
export class CommonModule {}
