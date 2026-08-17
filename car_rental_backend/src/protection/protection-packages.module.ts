import { Module } from '@nestjs/common';
import { ProtectionPackagesService } from './protection-packages.service';
import { ProtectionPackagesController } from './protection-packages.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ProtectionPackagesController],
  providers: [ProtectionPackagesService],
  exports: [ProtectionPackagesService],
})
export class ProtectionPackagesModule {}
