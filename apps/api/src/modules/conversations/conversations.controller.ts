import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards
} from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import {
  CreateConversationDto,
  AddMemberDto,
  ChangeMemberRoleDto,
  UpdateConversationDto
} from './dto/conversation.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Post()
  create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateConversationDto
  ) {
    return this.conversationsService.createConversation(userId, dto);
  }

  @Get()
  list(@CurrentUser('userId') userId: string) {
    return this.conversationsService.listUserConversations(userId);
  }

  @Get(':id')
  get(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string
  ) {
    return this.conversationsService.getConversation(userId, conversationId);
  }

  @Patch(':id')
  update(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string,
    @Body() dto: UpdateConversationDto
  ) {
    return this.conversationsService.updateConversation(userId, conversationId, dto);
  }

  @Post(':id/members')
  addMember(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string,
    @Body() dto: AddMemberDto
  ) {
    return this.conversationsService.addMember(userId, conversationId, dto);
  }

  @Patch(':id/members/:targetUserId')
  changeMemberRole(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string,
    @Param('targetUserId') targetUserId: string,
    @Body() dto: ChangeMemberRoleDto
  ) {
    return this.conversationsService.changeMemberRole(userId, conversationId, targetUserId, dto.role);
  }

  @Delete(':id/members/:targetUserId')
  removeMember(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string,
    @Param('targetUserId') targetUserId: string
  ) {
    return this.conversationsService.removeMember(userId, conversationId, targetUserId);
  }

  @Post(':id/leave')
  leave(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string
  ) {
    return this.conversationsService.leaveGroup(userId, conversationId);
  }

  @Delete(':id')
  delete(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string
  ) {
    return this.conversationsService.deleteConversation(userId, conversationId);
  }

  @Get(':id/messages')
  listMessages(
    @CurrentUser('userId') userId: string,
    @Param('id') conversationId: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string
  ) {
    return this.conversationsService.listMessages(userId, conversationId, limit, cursor);
  }
}

