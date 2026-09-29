import { Module } from '@nestjs/common';
import { MessagingService } from './messaging.service';
import { MessagingController } from './messaging.controller';
import { AuthenticationModule } from '../authentication/authentication.module';
import { SeaweedFsModule } from '../../infrastructure/seaweedfs/seaweedfs.module';

@Module({
  imports: [AuthenticationModule, SeaweedFsModule],
  controllers: [MessagingController],
  providers: [MessagingService],
  exports: [MessagingService]
})
export class MessagingModule {}
