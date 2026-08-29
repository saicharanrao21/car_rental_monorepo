import { Module, Global } from '@nestjs/common';
import { GeospatialService } from './geospatial.service';

@Global()
@Module({
  providers: [GeospatialService],
  exports: [GeospatialService],
})
export class GeospatialModule {}
export * from './geospatial.service';
