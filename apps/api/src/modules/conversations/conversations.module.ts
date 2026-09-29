import { Module } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { ConversationsController } from './conversations.controller';
import { AuthenticationModule } from '../authentication/authentication.module';
import { SeaweedFsModule } from '../../infrastructure/seaweedfs/seaweedfs.module';

@Module({
  imports: [AuthenticationModule, SeaweedFsModule],
  controllers: [ConversationsController],
  providers: [ConversationsService],
  exports: [ConversationsService]
})
export class ConversationsModule {}
