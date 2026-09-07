import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { ServiceAreasService } from './service-areas.service';
import { ServiceAreasController } from './service-areas.controller';

@Module({
  imports: [PrismaModule],
  controllers: [LocationsController, ServiceAreasController],
  providers: [LocationsService, ServiceAreasService],
  exports: [LocationsService, ServiceAreasService],
})
export class LocationsModule {}
export * from './service-areas.service';
export * from './dto/service-area.dto';
