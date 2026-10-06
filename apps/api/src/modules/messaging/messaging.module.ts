import { Module } from '@nestjs/common';
import { MessagingService } from './messaging.service';
import { MessagingController } from './messaging.controller';
import { ChatGateway } from './chat.gateway';
import { AuthenticationModule } from '../authentication/authentication.module';
import { ConversationsModule } from '../conversations/conversations.module';
import { SeaweedFsModule } from '../../infrastructure/seaweedfs/seaweedfs.module';

@Module({
  imports: [AuthenticationModule, ConversationsModule, SeaweedFsModule],
  controllers: [MessagingController],
  providers: [MessagingService, ChatGateway],
  exports: [MessagingService, ChatGateway]
})
export class MessagingModule {}

