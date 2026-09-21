import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

@Injectable()
export class SynchronizationService {
  constructor(private readonly prisma: PrismaService) {}

  async syncConversation(userId: string, conversationId: string, cursor?: number, limit = 50) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    const where: any = { conversationId };
    if (cursor !== undefined && !isNaN(cursor)) {
      where.sequence = { gt: cursor };
    }

    const events = await this.prisma.conversationEvent.findMany({
      where,
      orderBy: { sequence: 'asc' },
      take: Math.min(limit, 100)
    });

    const lastEvent = events[events.length - 1];
    const nextCursor = lastEvent ? lastEvent.sequence : cursor || 0;
    const hasMore = events.length === Math.min(limit, 100);

    return {
      conversationId,
      events: events.map((e) => ({
        id: e.id,
        eventType: e.eventType,
        payload: JSON.parse(e.payload),
        sequence: e.sequence,
        createdAt: e.createdAt
      })),
      nextCursor,
      hasMore
    };
  }
}
