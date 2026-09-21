import {
  Controller,
  Post,
  Delete,
  Param,
  Body,
  UseGuards
} from '@nestjs/common';
import { MessagingService } from './messaging.service';
import { SendMessageDto } from './dto/message.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller()
@UseGuards(JwtAuthGuard)
export class MessagingController {
  constructor(private readonly messagingService: MessagingService) {}

  @Post('conversations/:id/messages')
  sendMessage(
    @CurrentUser('userId') userId: string,
    @CurrentUser('deviceId') deviceId: string,
    @Param('id') conversationId: string,
    @Body() dto: SendMessageDto
  ) {
    return this.messagingService.sendMessage(userId, deviceId, conversationId, dto);
  }

  @Delete('messages/:id')
  deleteMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') messageId: string
  ) {
    return this.messagingService.deleteForEveryone(userId, messageId);
  }

  @Post('messages/:id/delivery')
  ackDelivery(
    @CurrentUser('deviceId') deviceId: string,
    @Param('id') messageId: string
  ) {
    return this.messagingService.acknowledgeDelivery(deviceId, messageId);
  }

  @Post('messages/:id/read')
  markRead(
    @CurrentUser('deviceId') deviceId: string,
    @Param('id') messageId: string
  ) {
    return this.messagingService.markRead(deviceId, messageId);
  }
}
