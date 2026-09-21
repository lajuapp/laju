import { Global, Module } from '@nestjs/common';
import { SeaweedFsService } from './seaweedfs.service';

@Global()
@Module({
  providers: [SeaweedFsService],
  exports: [SeaweedFsService]
})
export class SeaweedFsModule {}
