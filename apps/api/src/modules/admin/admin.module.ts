import { Module } from '@nestjs/common';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { SeaweedFsModule } from '../../infrastructure/seaweedfs/seaweedfs.module';

@Module({
  imports: [SeaweedFsModule],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService]
})
export class AdminModule {}
