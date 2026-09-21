import { Controller, Get, Query, UseGuards, BadRequestException } from '@nestjs/common';
import { SynchronizationService } from './synchronization.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SynchronizationController {
  constructor(private readonly syncService: SynchronizationService) {}

  @Get()
  sync(
    @CurrentUser('userId') userId: string,
    @Query('conversation_id') conversationId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string
  ) {
    if (!conversationId) {
      throw new BadRequestException('conversation_id parameter is required');
    }
    const numCursor = cursor ? parseInt(cursor, 10) : undefined;
    const numLimit = limit ? parseInt(limit, 10) : 50;

    return this.syncService.syncConversation(userId, conversationId, numCursor, numLimit);
  }
}
